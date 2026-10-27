import test from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync,readdirSync } from 'node:fs';
import worker from '../src/index.js';
function fixture(){
 const sql=new DatabaseSync(':memory:');
 for(const f of readdirSync(new URL('../migrations/',import.meta.url)).sort())sql.exec(readFileSync(new URL('../migrations/'+f,import.meta.url),'utf8'));
 const DB={sql,prepare(query){let args=[];const s=sql.prepare(query);return {
  bind(...v){args=v;return this;},async first(){return s.get(...args)??null;},async all(){return {results:s.all(...args)};},async run(){return {meta:{changes:Number(s.run(...args).changes)}};}
 };}};
 return {DB,ADMIN_TOKEN:'test-only-operator-token'};
}
async function call(env,path,body,headers={},method=body===undefined?'GET':'POST'){
 const r=await worker.fetch(new Request('https://farm.test'+path,{method,headers:{'content-type':'application/json',...headers},...(body===undefined?{}:{body:JSON.stringify(body)})}),env);
 return {status:r.status,data:await r.json(),headers:r.headers};
}
async function enroll(env,id='node1',farm='farm1'){
 const r=await call(env,'/v1/admin/enroll',{farm_id:farm,farm_name:'Test Farm',object_id:id},{'x-admin-token':env.ADMIN_TOKEN});
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
 const e=fixture(),a=await enroll(e),b=await enroll(e,'node2','farm2');const state={kind:'livestock',metrics:{animals:2}};
 assert.equal((await call(e,'/v1/state/sync',{revision:0,state},auth(a))).data.revision,1);
 assert.equal((await call(e,'/v1/state/sync',{revision:0,state:{bad:1}},auth(a))).status,409);
 assert.deepEqual((await call(e,'/v1/state',undefined,auth(a))).data.state,state);
 assert.deepEqual((await call(e,'/v1/state',undefined,auth(b))).data.state,{});
});
test('invalid bodies and oversized states cannot mutate records',async()=>{
 const e=fixture(),token=await enroll(e);
 for(const body of [null,[],{revision:1.5,state:{}},{revision:-1,state:{}},{revision:0,state:[]}])assert.equal((await call(e,'/v1/state/sync',body,auth(token))).status,400);
 assert.equal((await call(e,'/v1/state/sync',{revision:0,state:{text:'a'.repeat(12001)}},auth(token))).status,413);
 assert.equal((await call(e,'/v1/state',undefined,auth(token))).data.revision,0);
});
test('rotation yields URL-safe credential and invalidates prior token',async()=>{
 const e=fixture(),old=await enroll(e);const r=await call(e,'/v1/admin/rotate',{farm_id:'farm1',object_id:'node1'},{'x-admin-token':e.ADMIN_TOKEN});
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
 const e=fixture(),a=await enroll(e),b=await enroll(e,'node2','farm2');
 await call(e,'/v1/state/sync',{revision:0,state:{kind:'livestock',metrics:{animals:3}}},auth(a));
 await call(e,'/v1/state/sync',{revision:0,state:{kind:'equipment',metrics:{equipment:1}}},auth(b));
 await call(e,'/v1/admin/bootstrap',adminInput,{'x-admin-token':e.ADMIN_TOKEN});const cookie=await login(e);
 assert.deepEqual((await call(e,'/v1/admin/summary',undefined,{cookie})).data.totals,{animals:3,active_crops:null,equipment:1});
 assert.deepEqual((await call(e,'/v1/admin/summary?farm_id=farm1',undefined,{cookie})).data.totals,{animals:3,active_crops:null,equipment:null});
 assert.equal((await call(e,'/v1/admin/summary?farm_id=missing',undefined,{cookie})).status,404);
 e.DB.sql.prepare("UPDATE farm_objects SET updated_at='2000-01-01 00:00:00'").run();
 const stale=await call(e,'/v1/admin/summary',undefined,{cookie});assert.deepEqual(stale.data.totals,{animals:null,active_crops:null,equipment:null});
 assert.ok(stale.data.telemetry.every(o=>o.stale && !o.reporting));
});
