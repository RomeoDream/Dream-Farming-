import json
import unittest
from world import World,Network
from test_expansion import bag

class StableChainTests(unittest.IsolatedAsyncioTestCase):
    async def setup_chain(self):
        n=Network();h=await World('Herd',n).boot();s=await World('EquineStable',n).boot();c=await World('Compost',n).boot()
        await s.action('Set Herd');await s.choose(str(h.key));await s.action('More');await s.choose('Set compost');await s.choose(str(c.key))
        await bag(h,MANURE=20);await h.target(s)
        await h.action('Export');await h.choose('Select material');await h.choose('Manure')
        return n,h,s,c

    async def test_two_hop_manure_lost_ack_reset_at_each_end(self):
        n,h,s,c=await self.setup_chain()
        n.drop=lambda src,dst,ch,msg: ch==s.s.NET and json.loads(msg).get('op')=='ACK'
        await h.choose('Send 10');await n.drain();self.assertEqual(s.s.manure,10)
        await h.boot();await s.boot();n.drop=lambda *args:False
        await h.step(15);await n.drain();self.assertEqual(s.s.manure,10);self.assertEqual(await h.s.stock('MANURE'),10)
        await s.action('Muck out');self.assertEqual(s.s.collectedManure,10);self.assertEqual(s.s.manure,0)
        await s.action('More');await s.choose('Send manure');self.assertEqual(s.s.pendingTarget,c.key)
        n.drop=lambda src,dst,ch,msg: ch==s.s.NET and json.loads(msg).get('op')=='ACK'
        await s.step(60);await n.drain();self.assertEqual(c.saved()[8],10)
        await s.boot();await c.boot();n.drop=lambda *args:False
        await s.step(60);await n.drain();self.assertEqual(c.saved()[8],10);self.assertEqual(s.s.collectedManure,0)

    async def test_manure_receipt_failure_locks_and_never_acks(self):
        n,h,s,c=await self.setup_chain();s.fail_writes=True
        await h.choose('Send 10');await n.drain();self.assertEqual(s.s.manure,0);self.assertTrue(s.s.storageFault)
        self.assertEqual(h.saved()[h.s.OUT+2],10)
        s.fail_writes=False;await s.boot();await h.step(15);await n.drain();self.assertEqual(s.s.manure,10)
        self.assertEqual(h.saved()[h.s.OUT+2],0)

    async def test_manure_ack_failure_reconciles_without_double_compost(self):
        n,h,s,c=await self.setup_chain();await h.choose('Send 10');await n.drain();await s.action('Muck out')
        await s.action('More');await s.choose('Send manure');await s.step(60);s.fail_writes=True;await n.drain()
        self.assertEqual(s.s.collectedManure,10);self.assertEqual(s.s.pendingWater,10)
        s.fail_writes=False;await s.boot();await s.step(60);await n.drain()
        self.assertEqual(s.s.collectedManure,0);self.assertEqual(c.saved()[8],10)

    async def test_welfare_reports_actual_herd_metrics_without_local_consumption(self):
        n,h,s,c=await self.setup_chain();await h.submenu('Manage','Equines');await h.choose('Jenny')
        a=await h.s.animal(0);a[6]=72.;a[7]=11.;a[8]=22.;a[9]=33.
        await h.s.putAnimal(0,a);await h.s.save(list(h.s.S))
        await s.action('Assign UUID');await s.choose(a[0]);await n.drain()
        await s.action('Add hay');await s.action('Add water');await s.action('Care on');await s.step(60);await n.drain()
        self.assertIn('72',s.s.welfareText);self.assertIn('22',s.s.welfareText)
        self.assertEqual(s.s.hay,25);self.assertEqual(s.s.water,50);self.assertEqual(s.s.welfareAt,s.now)
        a[15]=0;await h.s.putAnimal(0,a);await h.s.save(list(h.s.S));await s.step(60);await n.drain()
        self.assertIn('unavailable',s.s.welfareText)

    async def test_v3_pending_water_snapshot_migrates_with_locked_destination(self):
        n,h,s,c=await self.setup_chain();await s.action('Add water');await s.action('Send water')
        v=json.loads(s.store[s.s.SNAPSHOT]);v=v[:20];v[0]=3;s.store[s.s.SNAPSHOT]=json.dumps(v)
        await s.boot();self.assertEqual(s.s.pendingTarget,h.key);self.assertEqual(json.loads(s.store[s.s.SNAPSHOT])[0],4)
        await s.step(60);await n.drain();self.assertEqual(s.s.water,40)

    async def test_fake_manure_and_mismatched_receipt_cannot_credit(self):
        n,h,s,c=await self.setup_chain();foreign=await World('Herd',n).boot()
        msg=dict(v=1,op='LOAD',target=str(s.key),stream=s.s.transferStream,seq=1,qty=10,kind='MANURE')
        await s.event('listen',s.s.NET,'Fake',foreign.key,json.dumps(msg));self.assertEqual(s.s.manure,0)
        await s.event('listen',s.s.NET,'Herd',h.key,json.dumps(msg));self.assertEqual(s.s.manure,10)
        msg['qty']=11;await s.event('listen',s.s.NET,'Herd',h.key,json.dumps(msg));self.assertEqual(s.s.manure,10)
        msg['seq']=2;msg['qty']=1.5;await s.event('listen',s.s.NET,'Herd',h.key,json.dumps(msg));self.assertEqual(s.s.manure,10)

    async def test_receipt_stream_limit_never_evicts_or_accepts_ninth(self):
        import uuid
        n,h,s,c=await self.setup_chain()
        for i in range(9):
            msg=dict(v=1,op='LOAD',target=str(s.key),stream=str(uuid.uuid4()),seq=1,qty=10,kind='MANURE')
            await s.event('listen',s.s.NET,'Herd',h.key,json.dumps(msg))
        self.assertEqual(s.s.manure,80);self.assertEqual(len(s.s.manureReceipts),24)
        await s.boot();self.assertEqual(s.s.manure,80);self.assertFalse(s.s.storageFault)

    async def test_animal_ids_menu_prints_record_uuid(self):
        n,h,s,c=await self.setup_chain();await h.submenu('Manage','Equines');await h.choose('Jack')
        a=await h.s.animal(0);await h.choose('Animal IDs')
        self.assertTrue(any(a[0] in line for line in h.chat))
