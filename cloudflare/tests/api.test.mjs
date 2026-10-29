import test from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync,readdirSync } from 'node:fs';
import worker from '../src/index.js';
const FARM1='10000000-0000-0000-0000-000000000001',FARM2='10000000-0000-0000-0000-000000000002';
const OBJECT1='20000000-0000-0000-0000-000000000001',OBJECT2='20000000-0000-0000-0000-000000000002';
const OWNER1='30000000-0000-0000-0000-000000000001',OWNER2='30000000-0000-0000-0000-000000000002';
function fixture(applyUUID=true){
 const sql=new DatabaseSync(':memory:');
 for(const f of readdirSync(new URL('../migrations/',import.meta.url)).sort().filter(f=>applyUUID || f!=='0004_sl_uuid_identity.sql'))sql.exec(readFileSync(new URL('../migrations/'+f,import.meta.url),'utf8'));
 const DB={sql,async batch(statements){sql.exec('BEGIN');try{const result=[];for(const statement of statements)result.push(await statement.run());sql.exec('COMMIT');return result;}catch(error){sql.exec('ROLLBACK');throw error;}},prepare(query){let args=[];const s=sql.prepare(query);return {
  bind(...v){args=v;return this;},async first(){return s.get(...args)??null;},async all(){return {results:s.all(...args)};},async run(){return {meta:{changes:Number(s.run(...args).changes)}};}
 };}};
 return {DB,ADMIN_TOKEN:'test-only-operator-token'};
}
async function call(env,path,body,headers={},method=body===undefined?'GET':'POST'){
 const r=await worker.fetch(new Request('https://farm.test'+path,{method,headers:{'content-type':'application/json',...headers},...(body===undefined?{}:{body:JSON.stringify(body)})}),env);
 return {status:r.status,data:await r.json(),headers:r.headers};
}
async function enroll(env,id=OBJECT1,farm=FARM1){
 const r=await call(env,'/v1/admin/enroll',{farm_id:farm,farm_name:'Test Farm',object_id:id,owner_uuid:farm===FARM1?OWNER1:OWNER2},{'x-admin-token':env.ADMIN_TOKEN});
 assert.equal(r.status,201);return r.data.credential;
}
const auth=token=>({authorization:'Bearer '+token});
test('health and object authentication',async()=>{
 const e=fixture();assert.equal((await call(e,'/health')).status,200);assert.equal((await call(e,'/v1/state')).status,401);
 assert.equal((await call(e,'/v1/admin/enroll',{})).status,401);
 const token=await enroll(e);assert.match(token,/^[A-Za-z0-9_-]{43}$/);
 const r=await call(e,'/v1/state',undefined,auth(token));assert.deepEqual(r.data.state,{});assert.equal(r.data.revision,0);
});
test('revision updates isolate farms and reject retries with stale revision',async()=>{
 const e=fixture(),a=await enroll(e),b=await enroll(e,OBJECT2,FARM2);const state={kind:'livestock',metrics:{animals:2},object_id:OBJECT1,owner_uuid:OWNER1};
 assert.equal((await call(e,'/v1/state/sync',{revision:0,state},auth(a))).data.revision,1);
 assert.equal((await call(e,'/v1/state/sync',{revision:0,state:{bad:1,object_id:OBJECT1,owner_uuid:OWNER1}},auth(a))).status,409);
 assert.deepEqual((await call(e,'/v1/state',undefined,auth(a))).data.state,state);
 assert.deepEqual((await call(e,'/v1/state',undefined,auth(b))).data.state,{});
});
test('invalid bodies and oversized states cannot mutate records',async()=>{
 const e=fixture(),token=await enroll(e);
 for(const body of [null,[],{revision:1.5,state:{}},{revision:-1,state:{}},{revision:0,state:[]}])assert.equal((await call(e,'/v1/state/sync',body,auth(token))).status,400);
 assert.equal((await call(e,'/v1/state/sync',{revision:0,state:{text:'a'.repeat(12001),object_id:OBJECT1,owner_uuid:OWNER1}},auth(token))).status,413);
 assert.equal((await call(e,'/v1/state',undefined,auth(token))).data.revision,0);
});
test('rotation yields URL-safe credential and invalidates prior token',async()=>{
 const e=fixture(),old=await enroll(e);const r=await call(e,'/v1/admin/rotate',{farm_id:FARM1,object_id:OBJECT1},{'x-admin-token':e.ADMIN_TOKEN});
 assert.equal(r.status,200);assert.match(r.data.credential,/^[A-Za-z0-9_-]{43}$/);
 assert.equal((await call(e,'/v1/state',undefined,auth(old))).status,401);assert.equal((await call(e,'/v1/state',undefined,auth(r.data.credential))).status,200);
 e.DB.sql.prepare('UPDATE farm_objects SET revoked=1').run();assert.equal((await call(e,'/v1/state',undefined,auth(r.data.credential))).status,401);
});
const adminInput={username:'RomeoDream',password:'test-only-long-password'};
async function login(e){const r=await call(e,'/v1/admin/login',adminInput);assert.equal(r.status,200);assert.match(r.headers.get('set-cookie'),/HttpOnly; Secure; SameSite=Strict/);return r.headers.get('set-cookie').split(';')[0];}
test('one-time administrator bootstrap and logout preserve account',async()=>{
 const e=fixture(),headers={'x-admin-token':e.ADMIN_TOKEN};
 assert.equal((await call(e,'/v1/admin/bootstrap',adminInput,headers)).status,201);assert.equal((await call(e,'/v1/admin/bootstrap',adminInput,headers)).status,409);
 assert.equal((await call(e,'/v1/admin/login',{...adminInput,password:'wrong'})).status,401);
 const cookie=await login(e);assert.equal((await call(e,'/v1/admin/summary',undefined,{cookie})).status,200);
 await call(e,'/v1/admin/logout',{}, {cookie});assert.equal((await call(e,'/v1/admin/summary',undefined,{cookie})).status,401);
 assert.equal(e.DB.sql.prepare('SELECT COUNT(*) n FROM admin_accounts').get().n,1);
});
test('dashboard totals are reported metrics and farm-specific',async()=>{
 const e=fixture(),a=await enroll(e),b=await enroll(e,OBJECT2,FARM2);
 await call(e,'/v1/state/sync',{revision:0,state:{kind:'livestock',metrics:{animals:3},object_id:OBJECT1,owner_uuid:OWNER1}},auth(a));
 await call(e,'/v1/state/sync',{revision:0,state:{kind:'equipment',metrics:{equipment:1},object_id:OBJECT2,owner_uuid:OWNER2}},auth(b));
 await call(e,'/v1/admin/bootstrap',adminInput,{'x-admin-token':e.ADMIN_TOKEN});const cookie=await login(e);
 assert.deepEqual((await call(e,'/v1/admin/summary',undefined,{cookie})).data.totals,{animals:3,active_crops:null,equipment:1});
 assert.deepEqual((await call(e,'/v1/admin/summary?farm_id='+FARM1,undefined,{cookie})).data.totals,{animals:3,active_crops:null,equipment:null});
 assert.equal((await call(e,'/v1/admin/summary?farm_id=missing',undefined,{cookie})).status,404);
 e.DB.sql.prepare("UPDATE farm_objects SET updated_at='2000-01-01 00:00:00'").run();
 const stale=await call(e,'/v1/admin/summary',undefined,{cookie});assert.deepEqual(stale.data.totals,{animals:null,active_crops:null,equipment:null});
 assert.ok(stale.data.telemetry.every(o=>o.stale && !o.reporting));
});

test('SL registration rejects slugs/null UUIDs and conflicting farm owners',async()=>{
 const e=fixture(),headers={'x-admin-token':e.ADMIN_TOKEN};
 for(const change of [{farm_id:'my-farm'},{object_id:'machine-one'},{owner_uuid:'Romeo Dream'},{object_id:'00000000-0000-0000-0000-000000000000'}]){
  const r=await call(e,'/v1/admin/enroll',{farm_id:FARM1,object_id:OBJECT1,owner_uuid:OWNER1,farm_name:'My farm',...change},headers);assert.equal(r.status,400);
 }
 assert.equal(e.DB.sql.prepare('SELECT COUNT(*) n FROM farms').get().n,0);
 await enroll(e);const r=await call(e,'/v1/admin/enroll',{farm_id:FARM1,object_id:OBJECT2,owner_uuid:OWNER2,farm_name:'Other owner'},headers);
 assert.equal(r.status,409);assert.equal(e.DB.sql.prepare('SELECT COUNT(*) n FROM farm_objects').get().n,1);
});
test('duplicate root-object registration cannot leave a new orphan farm',async()=>{
 const e=fixture();await enroll(e);
 const r=await call(e,'/v1/admin/enroll',{farm_id:FARM2,object_id:OBJECT1,owner_uuid:OWNER2,farm_name:'Collision'},{'x-admin-token':e.ADMIN_TOKEN});
 assert.equal(r.status,409);assert.equal(e.DB.sql.prepare('SELECT COUNT(*) n FROM farms').get().n,1);
});
test('registered UUID must match both telemetry owner and root object',async()=>{
 const e=fixture(),token=await enroll(e);
 for(const state of [{object_id:OBJECT2,owner_uuid:OWNER1},{object_id:OBJECT1,owner_uuid:OWNER2},{}])assert.equal((await call(e,'/v1/state/sync',{revision:0,state},auth(token))).status,403);
 assert.equal((await call(e,'/v1/state',undefined,auth(token))).data.revision,0);
});
test('farm account sign-in uses avatar UUID plus farm UUID and password',async()=>{
 const e=fixture();await enroll(e);const headers={'x-admin-token':e.ADMIN_TOKEN},password='test-farm-password';
 assert.equal((await call(e,'/v1/admin/accounts',{farm_id:FARM1,owner_uuid:OWNER1,password},headers)).status,201);
 const logged=await call(e,'/v1/auth/login',{farm_id:FARM1,owner_uuid:OWNER1,password});assert.equal(logged.status,200);
 assert.equal(logged.data.owner_uuid,OWNER1);assert.equal(logged.data.farm_id,FARM1);
 const me=await call(e,'/v1/auth/me',undefined,auth(logged.data.token));assert.equal(me.data.owner_uuid,OWNER1);
 assert.equal((await call(e,'/v1/auth/login',{farm_id:FARM1,owner_uuid:OWNER2,password})).status,401);
 assert.equal((await call(e,'/v1/auth/login',{farm_id:FARM1,owner_uuid:OWNER1,password:'incorrect-password'})).status,401);
});
test('explicit legacy mapping preserves inventory, controller token and account',async()=>{
 const e=fixture(false),headers={'x-admin-token':e.ADMIN_TOKEN};
 e.DB.sql.prepare("INSERT INTO farms(id,name) VALUES('legacy-farm','Existing farm')").run();
 const token='legacy_object_credential_123456789',hash=Buffer.from(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(token))).toString('hex');
 e.DB.sql.prepare("INSERT INTO farm_objects(id,farm_id,credential_hash) VALUES('legacy-node','legacy-farm',?)").run(hash);
 e.DB.sql.prepare("INSERT INTO inventory(farm_id,material,quantity) VALUES('legacy-farm','FEED',123)").run();
 e.DB.sql.prepare("INSERT INTO farm_accounts(farm_id,login_name,password_salt,password_hash) VALUES('legacy-farm','Old login','salt','oldhash')").run();
 e.DB.sql.exec(readFileSync(new URL('../migrations/0004_sl_uuid_identity.sql',import.meta.url),'utf8'));
 const data={legacy_farm_id:'legacy-farm',farm_id:FARM1,owner_uuid:OWNER1,objects:[{legacy_object_id:'legacy-node',object_id:OBJECT1}]};
 assert.equal((await call(e,'/v1/admin/bind-sl-identity',data,headers)).status,200);
 const state=await call(e,'/v1/state',undefined,auth(token));assert.equal(state.status,200);assert.equal(state.data.object_id,OBJECT1);assert.equal(state.data.farm_id,FARM1);
 assert.equal(e.DB.sql.prepare("SELECT quantity FROM inventory WHERE farm_id='legacy-farm'").get().quantity,123);
 assert.equal(e.DB.sql.prepare("SELECT password_hash FROM farm_accounts WHERE farm_id='legacy-farm'").get().password_hash,'oldhash');
 assert.equal((await call(e,'/v1/admin/bind-sl-identity',{...data,owner_uuid:OWNER2},headers)).status,409);
});
test('mapping collision rolls back every farm and object change',async()=>{
 const e=fixture();await enroll(e);
 e.DB.sql.prepare("INSERT INTO farms(id,name) VALUES('old','Preserve')").run();
 e.DB.sql.prepare("INSERT INTO farm_objects(id,farm_id,credential_hash) VALUES('old-node','old','not-an-active-token')").run();
 const r=await call(e,'/v1/admin/bind-sl-identity',{legacy_farm_id:'old',farm_id:FARM2,owner_uuid:OWNER2,objects:[{legacy_object_id:'old-node',object_id:OBJECT1}]},{'x-admin-token':e.ADMIN_TOKEN});
 assert.equal(r.status,409);assert.equal(e.DB.sql.prepare("SELECT sl_uuid FROM farms WHERE id='old'").get().sl_uuid,null);
});
test('signed-in administrator can approve registration without reentering secret',async()=>{
 const e=fixture();await call(e,'/v1/admin/bootstrap',adminInput,{'x-admin-token':e.ADMIN_TOKEN});const cookie=await login(e);
 const data={farm_id:FARM1,object_id:OBJECT1,owner_uuid:OWNER1,farm_name:'SL farm'};
 assert.equal((await call(e,'/v1/admin/enroll',data,{cookie,origin:'https://evil.test'})).status,401);
 assert.equal((await call(e,'/v1/admin/enroll',data,{cookie,origin:'https://farm.test'})).status,201);
});
