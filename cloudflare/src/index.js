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
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
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
