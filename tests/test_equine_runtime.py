"""Execute actual Stable/Herd LSL with lossy transport and storage failures."""
import json
import unittest
from world import World, Network, OTHER
from test_expansion import bag

class StableRuntimeTests(unittest.IsolatedAsyncioTestCase):
    async def pair(self):
        net=Network();h=await World('Herd',net).boot();s=await World('EquineStable',net).boot()
        await s.action('Set Herd');await s.choose(str(h.key))
        await s.action('Add water');await s.action('Add hay')
        return net,h,s

    async def reserve(self,s,kind='water'):
        if kind=='feed':await s.action('More')
        await s.action('Send '+kind)
        self.assertEqual(s.s.pendingWater,10)

    async def test_lost_ack_both_resets_and_duplicate_packets(self):
        for kind in ['water','feed']:
            net,h,s=await self.pair();await self.reserve(s,kind)
            net.drop=lambda source,target,ch,msg: json.loads(msg).get('op')=='ACK'
            await s.step(60);await net.drain()
            self.assertEqual(await h.s.stock(kind.upper()),10)
            self.assertEqual(s.s.pendingWater,10)
            await h.boot();await s.boot();net.drop=lambda *args:False
            await s.step(60);await net.drain()
            self.assertEqual(await h.s.stock(kind.upper()),10)
            self.assertEqual(s.s.pendingWater,0)
            self.assertEqual(s.s.water if kind=='water' else s.s.hay,40 if kind=='water' else 15)
            ack=[p for p in net.packets if p[2]==s.s.NET and json.loads(p[3]).get('op')=='ACK'][-1]
            await s.event('listen',ack[2],'Herd',ack[0],ack[3]);await s.boot()
            self.assertEqual(s.s.water if kind=='water' else s.s.hay,40 if kind=='water' else 15)

    async def test_reservation_save_failure_sends_nothing(self):
        net,h,s=await self.pair();before=dict(s.store);s.fail_writes=True
        await s.action('Send water');await s.step(60);await net.drain()
        self.assertTrue(s.s.storageFault);self.assertEqual(s.store,before)
        self.assertEqual(await h.s.stock('WATER'),0)
        s.fail_writes=False;await s.boot();self.assertEqual(s.s.pendingWater,0);self.assertEqual(s.s.water,50)

    async def test_ack_save_failure_retains_reservation_then_reconciles(self):
        net,h,s=await self.pair();await self.reserve(s)
        await s.step(60);s.fail_writes=True;await net.drain()
        self.assertTrue(s.s.storageFault);self.assertEqual(s.s.pendingWater,10);self.assertEqual(s.s.water,50)
        self.assertEqual(await h.s.stock('WATER'),10)
        s.fail_writes=False;await s.boot();await s.step(60);await net.drain()
        self.assertEqual(s.s.water,40);self.assertEqual(await h.s.stock('WATER'),10)

    async def test_receiver_save_failure_never_acks(self):
        net,h,s=await self.pair();await self.reserve(s);h.fail_writes=True
        await s.step(60);await net.drain();self.assertEqual(s.s.pendingWater,10)
        self.assertEqual(await h.s.stock('WATER'),0)
        h.fail_writes=False;await h.boot();await s.step(60);await net.drain()
        self.assertEqual(s.s.water,40);self.assertEqual(await h.s.stock('WATER'),10)

    async def test_retry_save_failure_sends_no_load(self):
        net,h,s=await self.pair();await self.reserve(s);s.fail_writes=True
        await s.step(60);await net.drain();self.assertEqual(await h.s.stock('WATER'),0)
        self.assertTrue(s.s.storageFault)

    async def test_copied_or_other_owner_snapshot_locks_without_overwrite(self):
        net,h,s=await self.pair();await self.reserve(s)
        clone=World('EquineStable',net);clone.store=dict(s.store);before=dict(clone.store)
        await clone.boot();await clone.step(60)
        self.assertTrue(clone.s.storageFault);self.assertEqual(clone.store,before)
        s.owner=OTHER;before=dict(s.store);await s.boot();await s.step(60)
        self.assertTrue(s.s.storageFault);self.assertEqual(s.store,before)
        self.assertEqual(await h.s.stock('WATER'),0)

    async def test_malformed_snapshot_is_preserved_and_locked(self):
        net,h,s=await self.pair();raw=json.loads(s.store[s.s.SNAPSHOT]);raw[13]=999
        s.store[s.s.SNAPSHOT]=json.dumps(raw);before=dict(s.store);await s.boot()
        self.assertTrue(s.s.storageFault);self.assertEqual(s.store,before)

    async def test_wrong_ack_and_out_of_range_retry_cannot_move_stock(self):
        net,h,s=await self.pair();await self.reserve(s)
        msg=dict(v=1,op='ACK',target=str(s.key),stream=s.s.transferStream,seq=s.s.transferSeq,qty=10,kind='FEED')
        await s.event('listen',s.s.NET,'Herd',h.key,json.dumps(msg));self.assertEqual(s.s.pendingWater,10)
        h.position=type(h.position)((20.,0.,0.));await s.step(60);await net.drain()
        self.assertEqual(await h.s.stock('WATER'),0)
        await s.action('Set Herd');self.assertEqual(s.s.herdRoot,h.key)

    async def test_verified_assignment_and_monitoring_no_double_consumption(self):
        net,h,s=await self.pair();await h.submenu('Manage','Equines');await h.choose('Mare')
        a=await h.s.animal(0);await s.action('Assign UUID');await s.choose(a[0]);await net.drain()
        self.assertEqual(list(s.s.assigned),[a[0]])
        await s.action('Care on');await s.step(3600)
        self.assertEqual(s.s.hay,25);self.assertEqual(s.s.water,50);self.assertEqual(s.s.manure,0)
        await s.boot();self.assertEqual(list(s.s.assigned),[a[0]])

    async def test_legacy_pending_delivery_migrates_atomically(self):
        net,h,s=await self.pair();await self.reserve(s)
        p=s.s.PREFIX;legacy={p+'stalls':'4',p+'owner':str(s.owner),p+'water':'50',p+'hay':'25',
          p+'herdRoot':str(h.key),p+'transferStream':s.s.transferStream,p+'transferSeq':'1',
          p+'pendingWater':'10',p+'pendingKind':'WATER',p+'pendingStarted':str(s.now),p+'verifiedAssignments':'1'}
        s.store=legacy;await s.boot();self.assertEqual(s.s.pendingWater,10)
        self.assertIn(s.s.SNAPSHOT,s.store);await s.step(60);await net.drain();self.assertEqual(s.s.water,40)

class EquineBirthTests(unittest.IsolatedAsyncioTestCase):
    async def test_horse_and_donkey_each_produce_one_pedigreed_foal(self):
        for female,male in [('Mare','Stallion'),('Jenny','Jack')]:
            h=await World('Herd').boot()
            await h.submenu('Manage','Equines');await h.choose(female)
            await h.submenu('Manage','Equines');await h.choose(male)
            await h.action('Breed');a=await h.s.animal(0);father=await h.s.animal(1)
            self.assertGreater(a[10],0);a[10]=0.;await h.s.putAnimal(0,a);await h.s.save(list(h.s.S))
            await bag(h,FEED=100,WATER=300);await h.step(150)
            self.assertEqual(await h.s.countAnimals(),3);child=await h.s.animal(2)
            self.assertEqual(child[11],father[0]);self.assertEqual(child[12],a[0]);self.assertEqual(child[2],a[2])
            await h.boot();await h.step(150);self.assertEqual(await h.s.countAnimals(),3)
