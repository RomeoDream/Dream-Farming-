// Regression coverage for credentials used by the existing Farm state-sync bridge.
// No live Cloudflare requests or real secrets. Copyright Romeo Dream.
import test from 'node:test';
import assert from 'node:assert/strict';
import { webcrypto } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import worker from '../src/index.js';
globalThis.crypto ??= webcrypto;

function fixture(changes=1) {
 const writes=[];
 return {ADMIN_TOKEN:'local-test-admin',writes,DB:{
  prepare(sql) {
   return {bind(...args) {
    return {async run() {writes.push({sql,args});return {meta:{changes}};}};
   }};
  }
 }};
}
const rotate=(env,body={farm_id:'farm-a',object_id:'object-a'},token='local-test-admin')=>worker.fetch(
 new Request('https://farm.invalid/v1/admin/rotate',{method:'POST',headers:{'x-admin-token':token},body:JSON.stringify(body)}),env);
test('rotated credentials use the exact alphabet accepted by object authentication',async()=>{
 const env=fixture(),seen=new Set();
 for(let i=0;i<16;i++){
  const r=await rotate(env);assert.equal(r.status,200);
  const {credential}=await r.json();assert.match(credential,/^[A-Za-z0-9_-]{43}$/);
  assert.ok(!seen.has(credential));seen.add(credential);
  const digest=Buffer.from(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(credential))).toString('hex');
  assert.equal(env.writes.at(-1).args[0],digest);
  assert.deepEqual(env.writes.at(-1).args.slice(1),['object-a','farm-a']);
  assert.match(env.writes.at(-1).sql,/revoked=0/);
 }
});
test('rotation needs the existing administrator secret before any database write',async()=>{
 const env=fixture();assert.equal((await rotate(env,undefined,'wrong')).status,401);
 delete env.ADMIN_TOKEN;assert.equal((await rotate(env)).status,401);assert.equal(env.writes.length,0);
});
test('rotation refuses missing, invalid and foreign object scope',async()=>{
 const env=fixture();
 for(const body of [{farm_id:'farm-a'},{farm_id:'../farm',object_id:'object-a'},{farm_id:'farm-a',object_id:''}])assert.equal((await rotate(env,body)).status,400);
 assert.equal(env.writes.length,0);
 const absent=fixture(0);const r=await rotate(absent);assert.equal(r.status,404);
 assert.ok(!('credential' in await r.json()));
});
test('real SQL rotation keeps state and tenant binding while invalidating old credential',async t=>{
 const sql=new DatabaseSync(':memory:');t.after(()=>sql.close());
 sql.exec('PRAGMA foreign_keys=ON');
 sql.exec(readFileSync(new URL('../migrations/0001_initial.sql',import.meta.url),'utf8'));
 const oldToken='a'.repeat(43);
 const oldHash=Buffer.from(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(oldToken))).toString('hex');
 sql.prepare('INSERT INTO farms(id,name) VALUES(?,?)').run('farm-a','Farm A');
 sql.prepare('INSERT INTO farm_objects(id,farm_id,credential_hash,state_json) VALUES(?,?,?,?)').run('object-a','farm-a',oldHash,'{"material":"HAY"}');
 const env={ADMIN_TOKEN:'local-test-admin',DB:{prepare(query){
  return {bind(...args){return {
   async run(){const r=sql.prepare(query).run(...args);return {meta:{changes:Number(r.changes)}};},
   async first(){return sql.prepare(query).get(...args)||null;}
  };}};
 }}};
 const get=token=>worker.fetch(new Request('https://farm.invalid/v1/state',{headers:{authorization:'Bearer '+token}}),env);
 assert.equal((await get(oldToken)).status,200);
 assert.equal((await rotate(env,{farm_id:'farm-b',object_id:'object-a'})).status,404);
 assert.equal((await get(oldToken)).status,200);
 const r=await rotate(env);assert.equal(r.status,200);const {credential}=await r.json();
 assert.equal((await get(oldToken)).status,401);
 const state=await get(credential);assert.equal(state.status,200);
 assert.deepEqual((await state.json()).state,{material:'HAY'});
 sql.exec("UPDATE farm_objects SET revoked=1 WHERE id='object-a'");
 assert.equal((await rotate(env)).status,404);assert.equal((await get(credential)).status,401);
});
