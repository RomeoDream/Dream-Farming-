import { dashboardPage } from "./dashboard.js";
import { adminLoginPage } from "./admin-login.js";
import { accountsPage } from "./accounts.js";
import { adminPage } from "./admin.js";
// Dream Farming Cloudflare API — first secure state-sync milestone.
// All authenticated endpoints require a per-object bearer credential.
// Provision objects through the operator-only enrollment endpoint.
const json = (data, status = 200) => new Response(JSON.stringify(data), {
  status, headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" }
});
const fail = (message, status) => json({ error: message }, status);
const hex = (buffer) => [...new Uint8Array(buffer)].map(x => x.toString(16).padStart(2, "0")).join("");
async function sha256(s) { return hex(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s))); }
async function readJson(request) {
  if (Number(request.headers.get("content-length") || 0) > 16384) throw new Error("payload_too_large");
  const raw = await request.text();
  if (raw.length > 16384) throw new Error("payload_too_large");
  return JSON.parse(raw);
}
function validId(s) { return typeof s === "string" && /^[a-zA-Z0-9_-]{1,80}$/.test(s); }
async function authenticate(request, env) {
  const token = request.headers.get("authorization")?.match(/^Bearer ([A-Za-z0-9_-]{24,128})$/)?.[1];
  if (!token) return null;
  const hash = await sha256(token);
  return env.DB.prepare("SELECT id, farm_id, revision FROM farm_objects WHERE credential_hash = ? AND revoked = 0").bind(hash).first();
}

// PBKDF2 password verification: unique random salt per farm account.
function encode(bytes) { return btoa(String.fromCharCode(...bytes)).split("+").join("-").split("/").join("_").replace(/=+$/,""); }
function decode(s) { return Uint8Array.from(atob(s.replace(/-/g,"+").replace(/_/g,"/")),c=>c.charCodeAt(0)); }
async function passwordHash(password,salt,iterations=100000) {
  const key=await crypto.subtle.importKey("raw",new TextEncoder().encode(password),"PBKDF2",false,["deriveBits"]);
  return encode(new Uint8Array(await crypto.subtle.deriveBits({name:"PBKDF2",salt:decode(salt),iterations,hash:"SHA-256"},key,256)));
}
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === "/dashboard" && request.method === "GET") return new Response(dashboardPage, {headers:{"content-type":"text/html; charset=utf-8","cache-control":"no-store"}});
    if (url.pathname === "/admin-login" && request.method === "GET") return new Response(adminLoginPage, { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store", "x-content-type-options": "nosniff", "content-security-policy": "frame-ancestors 'none'" } });
    if (url.pathname === "/farm-login" && request.method === "GET") return new Response(accountsPage, { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store", "x-content-type-options": "nosniff", "content-security-policy": "frame-ancestors 'none'" } });
    if (url.pathname === "/admin" && request.method === "GET") return new Response(adminPage, { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store", "x-content-type-options": "nosniff", "content-security-policy": "frame-ancestors 'none'" } });
    if (url.pathname === "/health" && request.method === "GET") return json({ ok: true, service: "dream-farming", version: 1 });
    if (url.pathname === "/v1/admin/enroll" && request.method === "POST") {
      // Configure ADMIN_TOKEN as a Worker secret, never in the repository.
      const provided = request.headers.get("x-admin-token");
      if (!env.ADMIN_TOKEN || !provided || provided !== env.ADMIN_TOKEN) return fail("unauthorized", 401);
      try {
        const data = await readJson(request);
        if (![data.farm_id, data.object_id].every(validId) || typeof data.farm_name !== "string" || !data.farm_name.trim() || data.farm_name.length > 120) return fail("invalid_input", 400);
        const bytes = crypto.getRandomValues(new Uint8Array(32));
        const credential = btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
        const hash = await sha256(credential);
        await env.DB.prepare("INSERT OR IGNORE INTO farms(id,name) VALUES(?,?)").bind(data.farm_id, data.farm_name).run();
        const inserted = await env.DB.prepare("INSERT OR IGNORE INTO farm_objects(id,farm_id,credential_hash) VALUES(?,?,?)").bind(data.object_id, data.farm_id, hash).run();
        if (inserted.meta.changes !== 1) return fail("object_already_exists", 409);
        return json({ object_id: data.object_id, farm_id: data.farm_id, credential }, 201);
      } catch (e) { return fail("invalid_request", 400); }
    }
    if (url.pathname === "/v1/admin/rotate" && request.method === "POST") {
      const provided = request.headers.get("x-admin-token");
      if (!env.ADMIN_TOKEN || !provided || provided !== env.ADMIN_TOKEN) return fail("unauthorized", 401);
      let data;
      try { data = await readJson(request); } catch { return fail("invalid_request", 400); }
      if (!validId(data.farm_id) || !validId(data.object_id)) return fail("invalid_input", 400);
      const bytes = crypto.getRandomValues(new Uint8Array(32));
      const credential = btoa(String.fromCharCode(...bytes)).replace(/\\+/g, "-").replace(/\\//g, "_").replace(/=+$/, "");
      const hash = await sha256(credential);
      const result = await env.DB.prepare("UPDATE farm_objects SET credential_hash=?,updated_at=CURRENT_TIMESTAMP WHERE id=? AND farm_id=? AND revoked=0").bind(hash, data.object_id, data.farm_id).run();
      if (result.meta.changes !== 1) return fail("object_not_found", 404);
      return json({ ok: true, object_id: data.object_id, credential });
    }
    if (url.pathname === "/v1/admin/accounts" && request.method === "POST") {
      if (!env.ADMIN_TOKEN || request.headers.get("x-admin-token") !== env.ADMIN_TOKEN) return fail("unauthorized",401);
      let data; try { data=await readJson(request); } catch { return fail("invalid_request",400); }
      if (!validId(data.farm_id) || typeof data.login_name!=="string" || data.login_name.trim().length<3 || data.login_name.length>120 || typeof data.password!=="string" || data.password.length<12 || data.password.length>256) return fail("invalid_input",400);
      const salt=encode(crypto.getRandomValues(new Uint8Array(16)));
      const hash=await passwordHash(data.password,salt);
      try {
        const r=await env.DB.prepare("INSERT INTO farm_accounts(farm_id,login_name,password_salt,password_hash,password_iterations) SELECT id,?,?,?,100000 FROM farms WHERE id=?").bind(data.login_name.trim(),salt,hash,data.farm_id).run();
        if(r.meta.changes!==1)return fail("farm_not_found",404);
        return json({ok:true,farm_id:data.farm_id},201);
      } catch { return fail("account_exists_or_invalid",409); }
    }
    if (url.pathname === "/v1/auth/login" && request.method === "POST") {
      let data; try { data=await readJson(request); } catch { return fail("invalid_request",400); }
      if(typeof data.login_name!=="string" || typeof data.password!=="string")return fail("invalid_credentials",401);
      const row=await env.DB.prepare("SELECT farm_id,password_salt,password_hash,password_iterations FROM farm_accounts WHERE login_name=? COLLATE NOCASE").bind(data.login_name).first();
      if(!row)return fail("invalid_credentials",401);
      const hash=await passwordHash(data.password,row.password_salt,row.password_iterations);
      if(hash!==row.password_hash)return fail("invalid_credentials",401);
      const token=encode(crypto.getRandomValues(new Uint8Array(32)));
      const tokenHash=await sha256(token);
      const expires=Math.floor(Date.now()/1000)+3600;
      await env.DB.prepare("INSERT INTO farm_sessions(token_hash,farm_id,expires_at) VALUES(?,?,?)").bind(tokenHash,row.farm_id,expires).run();
      return json({token,expires_at:expires,farm_id:row.farm_id});
    }
    if (url.pathname === "/v1/auth/me" && request.method === "GET") {
      const bearer=request.headers.get("authorization")?.match(/^Bearer ([A-Za-z0-9_-]{24,128})$/)?.[1];
      if(!bearer)return fail("unauthorized",401);
      const row=await env.DB.prepare("SELECT farm_id FROM farm_sessions WHERE token_hash=? AND expires_at>?").bind(await sha256(bearer),Math.floor(Date.now()/1000)).first();
      return row?json({farm_id:row.farm_id}):fail("unauthorized",401);
    }
    if (url.pathname === "/v1/admin/bootstrap" && request.method === "POST") {
      if (!env.ADMIN_TOKEN || request.headers.get("x-admin-token") !== env.ADMIN_TOKEN) return fail("unauthorized",401);
      let d; try { d=await readJson(request); } catch { return fail("invalid_request",400); }
      if(d.username!=="RomeoDream" || typeof d.password!=="string" || d.password.length<14 || d.password.length>256)return fail("invalid_input",400);
      let existing; try { existing=await env.DB.prepare("SELECT id FROM admin_accounts LIMIT 1").first(); } catch (e) { console.error("admin bootstrap database read failed",e); return fail("admin_database_unavailable",503); }
      if(existing)return fail("admin_already_exists",409);
      const salt=encode(crypto.getRandomValues(new Uint8Array(16)));
      let hash; try { hash=await passwordHash(d.password,salt); } catch (e) { console.error("admin password derivation failed",e); return fail("password_setup_unavailable",503); }
      try {
        await env.DB.prepare("INSERT INTO admin_accounts(id,username,password_salt,password_hash,password_iterations) VALUES(?,?,?,?,100000)").bind("primary-admin","RomeoDream",salt,hash).run();
        return json({ok:true,username:"RomeoDream"},201);
      } catch (e) { console.error("admin bootstrap insert failed",e); return fail("admin_database_write_failed",503); }
    }
    if (url.pathname === "/v1/admin/login" && request.method === "POST") {
      let d;try{d=await readJson(request);}catch{return fail("invalid_request",400);}
      if(typeof d.username!=="string"||typeof d.password!=="string")return fail("invalid_credentials",401);
      const row=await env.DB.prepare("SELECT id,username,password_salt,password_hash,password_iterations FROM admin_accounts WHERE username=? COLLATE NOCASE AND disabled=0").bind(d.username).first();
      if(!row)return fail("invalid_credentials",401);
      const hash=await passwordHash(d.password,row.password_salt,row.password_iterations);
      if(hash!==row.password_hash)return fail("invalid_credentials",401);
      const token=encode(crypto.getRandomValues(new Uint8Array(32)));
      const expires=Math.floor(Date.now()/1000)+1800;
      await env.DB.prepare("INSERT INTO admin_sessions(token_hash,admin_id,expires_at) VALUES(?,?,?)").bind(await sha256(token),row.id,expires).run();
      return new Response(JSON.stringify({ok:true,expires_at:expires,username:row.username}),{headers:{"content-type":"application/json","cache-control":"no-store","set-cookie":"dream_admin="+token+"; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=1800"}});
    }
    if (url.pathname === "/v1/admin/logout" && request.method === "POST") {
      const cookie=request.headers.get("cookie")?.split(";").map(x=>x.trim()).find(x=>x.startsWith("dream_admin="))?.slice(12);
      if(cookie)await env.DB.prepare("DELETE FROM admin_sessions WHERE token_hash=?").bind(await sha256(cookie)).run();
      return new Response(JSON.stringify({ok:true}),{headers:{"content-type":"application/json","set-cookie":"dream_admin=; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=0"}});
    }
    if (url.pathname === "/v1/admin/summary" && request.method === "GET") {
      const cookie=request.headers.get("cookie")?.split(";").map(x=>x.trim()).find(x=>x.startsWith("dream_admin="))?.slice(12);
      if(!cookie)return fail("unauthorized",401);
      const admin=await env.DB.prepare("SELECT a.id FROM admin_sessions s JOIN admin_accounts a ON a.id=s.admin_id WHERE s.token_hash=? AND s.expires_at>? AND a.disabled=0").bind(await sha256(cookie),Math.floor(Date.now()/1000)).first();
      if(!admin)return fail("unauthorized",401);
      const selected=url.searchParams.get("farm_id");
      if(selected && !validId(selected))return fail("invalid_farm_id",400);
      if(selected) {
        const farm=await env.DB.prepare("SELECT id,name FROM farms WHERE id=?").bind(selected).first();
        if(!farm)return fail("farm_not_found",404);
        const [objects,materials,transfers,inventory]=await Promise.all([
          env.DB.prepare("SELECT COUNT(*) n FROM farm_objects WHERE farm_id=?").bind(selected).first(),
          env.DB.prepare("SELECT COUNT(*) n FROM inventory WHERE farm_id=?").bind(selected).first(),
          env.DB.prepare("SELECT COUNT(*) n FROM transfer_receipts WHERE farm_id=?").bind(selected).first(),
          env.DB.prepare("SELECT material,quantity FROM inventory WHERE farm_id=? ORDER BY quantity DESC LIMIT 10").bind(selected).all()
        ]);
        const all=await env.DB.prepare("SELECT id,name FROM farms ORDER BY name LIMIT 100").all();
        return json({counts:{farms:1,objects:objects.n,materials:materials.n,transfers:transfers.n},farms:all.results,inventory:inventory.results,selected_farm:selected});
      }
      const [farms,objects,materials,transfers,list,inventory]=await Promise.all([
        env.DB.prepare("SELECT COUNT(*) n FROM farms").first(),
        env.DB.prepare("SELECT COUNT(*) n FROM farm_objects").first(),
        env.DB.prepare("SELECT COUNT(*) n FROM inventory").first(),
        env.DB.prepare("SELECT COUNT(*) n FROM transfer_receipts").first(),
        env.DB.prepare("SELECT id,name FROM farms ORDER BY name LIMIT 100").all(),
        env.DB.prepare("SELECT material,SUM(quantity) quantity FROM inventory GROUP BY material ORDER BY quantity DESC LIMIT 10").all()
      ]);
      return json({counts:{farms:farms.n,objects:objects.n,materials:materials.n,transfers:transfers.n},farms:list.results,inventory:inventory.results});
    }
    if (url.pathname === "/v1/admin/me" && request.method === "GET") {
      const bearer=request.headers.get("authorization")?.match(/^Bearer ([A-Za-z0-9_-]{24,128})$/)?.[1];
      if(!bearer)return fail("unauthorized",401);
      const row=await env.DB.prepare("SELECT a.username FROM admin_sessions s JOIN admin_accounts a ON a.id=s.admin_id WHERE s.token_hash=? AND s.expires_at>? AND a.disabled=0").bind(await sha256(bearer),Math.floor(Date.now()/1000)).first();
      return row?json({username:row.username}):fail("unauthorized",401);
    }
    if (!url.pathname.startsWith("/v1/")) return fail("not_found", 404);
    const identity = await authenticate(request, env);
    if (!identity) return fail("unauthorized", 401);
    if (url.pathname === "/v1/state/sync" && request.method === "POST") {
      let data;
      try { data = await readJson(request); } catch { return fail("invalid_json_or_size", 400); }
      if (!Number.isSafeInteger(data.revision) || data.revision < 0 || typeof data.state !== "object" || data.state === null || Array.isArray(data.state)) return fail("invalid_state", 400);
      const state = JSON.stringify(data.state);
      if (state.length > 12000) return fail("state_too_large", 413);
      const result = await env.DB.prepare("UPDATE farm_objects SET state_json=?,revision=revision+1,updated_at=CURRENT_TIMESTAMP WHERE id=? AND farm_id=? AND revision=? AND revoked=0")
        .bind(state, identity.id, identity.farm_id, data.revision).run();
      if (result.meta.changes !== 1) {
        const current = await env.DB.prepare("SELECT revision FROM farm_objects WHERE id=?").bind(identity.id).first();
        return json({ error: "revision_conflict", revision: current?.revision }, 409);
      }
      return json({ ok: true, revision: data.revision + 1 });
    }
    if (url.pathname === "/v1/state" && request.method === "GET") {
      const row = await env.DB.prepare("SELECT revision,state_json,updated_at FROM farm_objects WHERE id=? AND farm_id=?").bind(identity.id, identity.farm_id).first();
      return row ? json({ revision: row.revision, state: JSON.parse(row.state_json), updated_at: row.updated_at }) : fail("not_found", 404);
    }
    return fail("not_found", 404);
  }
};
