// SL UUIDs identify records. Private credentials/passwords authenticate callers.
export function slUUID(value) {
  return typeof value==='string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value) && value.toLowerCase()!=='00000000-0000-0000-0000-000000000000';
}
const normal=v=>v.toLowerCase();
export async function resolveFarm(env,id){
  if(!slUUID(id))return null;
  return env.DB.prepare('SELECT id,sl_uuid,owner_uuid,name FROM farms WHERE sl_uuid=?').bind(normal(id)).first();
}
export async function identityRoutes(request,env,{json,fail,readJson,sha256,encode,passwordHash}){
 const path=new URL(request.url).pathname;
 const adminRoutes=['/v1/admin/enroll','/v1/admin/rotate','/v1/admin/accounts','/v1/admin/bind-sl-identity'];
 if(request.method!=='POST' || ![...adminRoutes,'/v1/auth/login'].includes(path))return null;
 if(adminRoutes.includes(path)){
  let approved=!!env.ADMIN_TOKEN && request.headers.get('x-admin-token')===env.ADMIN_TOKEN;
  if(!approved){
   const cookie=request.headers.get('cookie')?.split(';').map(x=>x.trim()).find(x=>x.startsWith('dream_admin='))?.slice(12);
   const origin=request.headers.get('origin');
   if(cookie && (!origin || origin===new URL(request.url).origin)){
    approved=!!await env.DB.prepare('SELECT a.id FROM admin_sessions s JOIN admin_accounts a ON a.id=s.admin_id WHERE s.token_hash=? AND s.expires_at>? AND a.disabled=0').bind(await sha256(cookie),Math.floor(Date.now()/1000)).first();
   }
  }
  if(!approved)return fail('unauthorized',401);
 }
 let d;try{d=await readJson(request);}catch{return fail('invalid_request',400);}
 if(path==='/v1/admin/bind-sl-identity'){
  // Explicit migration only; never invent an owner's UUID from a display name.
  if(typeof d.legacy_farm_id!=='string' || !slUUID(d.farm_id) || !slUUID(d.owner_uuid) || !Array.isArray(d.objects) || d.objects.length>100)return fail('invalid_sl_identity',400);
  const farm=await env.DB.prepare('SELECT id,sl_uuid,owner_uuid FROM farms WHERE id=?').bind(d.legacy_farm_id).first();
  if(!farm)return fail('farm_not_found',404);
  const f=normal(d.farm_id),owner=normal(d.owner_uuid);
  if((farm.sl_uuid && farm.sl_uuid!==f) || (farm.owner_uuid && farm.owner_uuid!==owner))return fail('identity_already_bound',409);
  const statements=[env.DB.prepare('UPDATE farms SET sl_uuid=?,owner_uuid=? WHERE id=?').bind(f,owner,farm.id)];
  const ids=new Set(),keys=new Set();
  for(const o of d.objects){
   if(!o || typeof o.legacy_object_id!=='string' || !slUUID(o.object_id) || ids.has(o.legacy_object_id) || keys.has(normal(o.object_id)))return fail('invalid_object_mapping',400);
   ids.add(o.legacy_object_id);keys.add(normal(o.object_id));
   const row=await env.DB.prepare('SELECT id,sl_uuid FROM farm_objects WHERE id=? AND farm_id=?').bind(o.legacy_object_id,farm.id).first();
   if(!row)return fail('object_not_found',404);
   if(row.sl_uuid && row.sl_uuid!==normal(o.object_id))return fail('identity_already_bound',409);
   statements.push(env.DB.prepare('UPDATE farm_objects SET sl_uuid=? WHERE id=? AND farm_id=?').bind(normal(o.object_id),row.id,farm.id));
  }
  try{await env.DB.batch(statements);}catch{return fail('identity_conflict',409);}
  return json({ok:true,farm_id:f,owner_uuid:owner,mapped_objects:d.objects.length});
 }
 if(!slUUID(d.farm_id))return fail('invalid_farm_uuid',400);
 d.farm_id=normal(d.farm_id);
 if(path==='/v1/admin/enroll'){
  if(!slUUID(d.owner_uuid) || !slUUID(d.object_id) || typeof d.farm_name!=='string' || !d.farm_name.trim() || d.farm_name.length>120)return fail('invalid_sl_identity',400);
  const owner=normal(d.owner_uuid),object=normal(d.object_id);
  const existing=await resolveFarm(env,d.farm_id);
  if(existing && existing.owner_uuid!==owner)return fail('farm_owner_mismatch',409);
  const credential=encode(crypto.getRandomValues(new Uint8Array(32))),hash=await sha256(credential);
  // One D1 transaction: a duplicate object cannot leave an orphan farm behind.
  const internal=existing?.id??d.farm_id;
  try{await env.DB.batch([
   env.DB.prepare('INSERT INTO farms(id,name,sl_uuid,owner_uuid) VALUES(?,?,?,?) ON CONFLICT(id) DO NOTHING').bind(internal,d.farm_name.trim(),d.farm_id,owner),
   env.DB.prepare('INSERT INTO farm_objects(id,farm_id,credential_hash,sl_uuid) SELECT ?,id,?,? FROM farms WHERE id=? AND sl_uuid=? AND owner_uuid=?').bind(object,hash,object,internal,d.farm_id,owner)
  ]);}catch{return fail('object_or_identity_exists',409);}
  const created=await env.DB.prepare('SELECT id FROM farm_objects WHERE id=? AND credential_hash=?').bind(object,hash).first();
  if(!created)return fail('farm_identity_conflict',409);
  return json({farm_id:d.farm_id,owner_uuid:owner,object_id:object,credential},201);
 }
 const farm=await resolveFarm(env,d.farm_id);if(!farm)return fail('farm_not_found',404);
 if(path==='/v1/admin/rotate'){
  if(!slUUID(d.object_id))return fail('invalid_object_uuid',400);
  const credential=encode(crypto.getRandomValues(new Uint8Array(32)));
  const result=await env.DB.prepare('UPDATE farm_objects SET credential_hash=?,updated_at=CURRENT_TIMESTAMP WHERE sl_uuid=? AND farm_id=? AND revoked=0').bind(await sha256(credential),normal(d.object_id),farm.id).run();
  if(result.meta.changes!==1)return fail('object_not_found',404);
  return json({ok:true,object_id:normal(d.object_id),farm_id:d.farm_id,credential});
 }
 if(!slUUID(d.owner_uuid) || normal(d.owner_uuid)!==farm.owner_uuid)return fail('invalid_credentials',401);
 if(typeof d.password!=='string' || d.password.length<12 || d.password.length>256)return fail('invalid_credentials',401);
 if(path==='/v1/admin/accounts'){
  const salt=encode(crypto.getRandomValues(new Uint8Array(16))),hash=await passwordHash(d.password,salt);
  try{await env.DB.prepare('INSERT INTO farm_accounts(farm_id,login_name,password_salt,password_hash,password_iterations) VALUES(?,?,?,?,100000)').bind(farm.id,d.farm_id,salt,hash).run();}catch{return fail('account_exists',409);}
  return json({ok:true,farm_id:d.farm_id,owner_uuid:farm.owner_uuid},201);
 }
 const row=await env.DB.prepare('SELECT password_salt,password_hash,password_iterations FROM farm_accounts WHERE farm_id=?').bind(farm.id).first();
 if(!row || await passwordHash(d.password,row.password_salt,row.password_iterations)!==row.password_hash)return fail('invalid_credentials',401);
 const token=encode(crypto.getRandomValues(new Uint8Array(32))),expires=Math.floor(Date.now()/1000)+3600;
 await env.DB.prepare('INSERT INTO farm_sessions(token_hash,farm_id,expires_at) VALUES(?,?,?)').bind(await sha256(token),farm.id,expires).run();
 return json({token,expires_at:expires,farm_id:d.farm_id,owner_uuid:farm.owner_uuid});
}
