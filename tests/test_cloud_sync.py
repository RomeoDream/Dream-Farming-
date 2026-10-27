import json
import unittest
from world import World,OTHER
TOKEN='test_object_credential_123456789'
class CloudSyncTests(unittest.IsolatedAsyncioTestCase):
    async def ready(self):
        w=await World('CloudSync',OBJECT_TOKEN=TOKEN).boot();await w.step(30)
        r=w.http_requests[-1];self.assertTrue(r[1].endswith('/v1/state'))
        await w.event('http_response',r[0],200,[],json.dumps({'revision':0,'state':{}}))
        return w
    async def observe(self,w,**values):
        raw=dict(kind='HERD',fault=0,living=2);raw.update(values)
        await w.event('link_message',1,w.s.VIEW,json.dumps(raw),w.key)
    async def test_disabled_companion_never_uses_network(self):
        w=await World('CloudSync').boot();await self.observe(w);await w.step(300);self.assertEqual(w.http_requests,[])
    async def test_real_herd_metrics_and_http_revision_round_trip(self):
        w=await self.ready();h=await World('Herd').boot();await h.submenu('Manage','Equines');await h.choose('Mare')
        raw=await h.s.visual();await w.event('link_message',1,w.s.VIEW,raw,h.key)
        await w.step(60);r=w.http_requests[-1];data=json.loads(r[3]);self.assertEqual(data['revision'],0)
        self.assertEqual(data['state']['metrics'],{'animals':1})
        await w.event('http_response',r[0],200,[],json.dumps({'ok':True,'revision':1}));self.assertEqual(w.s.revision,1)
        await w.boot();await w.step(30);self.assertEqual(w.s.revision,-1);self.assertTrue(w.http_requests[-1][1].endswith('/v1/state'))
    async def test_conflict_and_lost_http_reply_get_revision_before_resend(self):
        w=await self.ready();await self.observe(w);await w.step(60);r=w.http_requests[-1]
        await w.event('http_response',r[0],409,[],json.dumps({'revision':3}));self.assertEqual(w.s.revision,-1)
        await w.step(60);self.assertTrue(w.http_requests[-1][1].endswith('/v1/state'))
        await w.step(90);self.assertEqual(w.s.requestId,'00000000-0000-0000-0000-000000000000')
        count=len(w.http_requests);await w.step(30);self.assertEqual(len(w.http_requests),count)
    async def test_unauthorized_and_copied_or_other_owner_binding_lock(self):
        w=await self.ready();await self.observe(w);await w.step(60);r=w.http_requests[-1]
        await w.event('http_response',r[0],401,[],'{}');self.assertTrue(w.s.blocked)
        clone=World('CloudSync',OBJECT_TOKEN=TOKEN);clone.store=dict(w.store);await clone.boot();await clone.step(60)
        self.assertTrue(clone.s.blocked);self.assertEqual(clone.http_requests,[])
        w.owner=OTHER;await w.boot();await w.step(60);self.assertTrue(w.s.blocked)
    async def test_faulted_stale_and_other_prim_data_never_publish(self):
        w=await self.ready();await self.observe(w,fault=1);await w.step(60);self.assertEqual(len(w.http_requests),1)
        await w.event('link_message',2,w.s.VIEW,json.dumps(dict(kind='MACHINE',fault=0)),w.key)
        self.assertEqual(w.s.latest,'');await self.observe(w);await self.observe(w,fault=1);self.assertEqual(w.s.latest,'');await self.observe(w);await w.step(120);self.assertEqual(len(w.http_requests),1)
    async def test_field_and_equipment_metrics_are_exact(self):
        w=await self.ready();await self.observe(w,kind='FIELD',crop=0)
        self.assertEqual(json.loads(w.s.latest)['metrics'],{'active_crops':0})
        await self.observe(w,kind='FIELD',crop=2);self.assertEqual(json.loads(w.s.latest)['metrics'],{'active_crops':1})
        await self.observe(w,kind='MACHINE');self.assertEqual(json.loads(w.s.latest)['metrics'],{'equipment':1})
    async def test_storage_failure_prevents_credential_use(self):
        w=World('CloudSync',OBJECT_TOKEN=TOKEN);w.fail_writes=True;await w.boot();await w.step(60)
        self.assertTrue(w.s.blocked);self.assertEqual(w.http_requests,[])
