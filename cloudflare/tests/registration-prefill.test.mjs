import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {registrationPage} from '../src/registration.js';
test('Farm page accepts shared entity UUID and retains existing administrator login',async()=>{
 const ids=new Map(),el=id=>{if(!ids.has(id))ids.set(id,{});return ids.get(id);};
 const source=registrationPage.match(/<script>([\s\S]*?)<\/script>/)[1];
 for(const query of ['?owner=owner&entity=shared&object=root','?owner=owner&farm=legacy&entity=shared&object=root']){
  vm.runInNewContext(source,{document:{getElementById:el},URLSearchParams,location:{pathname:'/register',search:query}});
  assert.equal(el('farm').value,query.includes('farm=')?'legacy':'shared');
  assert.equal(el('owner').value,'owner');assert.equal(el('object').value,'root');
  assert.ok(el('signin').href.startsWith('/admin-login?next='));
 }
});
