import json
import unittest
import lummao
from world import World, Network, OWNER, OTHER, NULL

async def bag(world, **items):
    for key,qty in items.items(): await world.s.alter(key,float(qty))
    await world.s.save(list(world.s.S))

class ProductionTests(unittest.IsolatedAsyncioTestCase):
    async def test_new_modules_valid_and_all_menus_fit(self):
        for name in ['Storage','Processor','Garden_Link']:
            w=await World(name).boot()
            self.assertTrue(await w.s.validBase(w.s.S));self.assertTrue(await w.s.validSpecific(w.s.S))
            for page in ['main','settings','material','recipe']:await w.s.show(page)
            before=w.saved();await w.boot();self.assertEqual(before,w.saved())

    async def test_field_export_to_dryer_and_storage(self):
        net=Network();field=await World('Field',net).boot();mill=await World('Processor',net).boot();store=await World('Storage',net).boot()
        await field.edit(**{'34':20.0});await field.target(mill)
        await field.submenu('Export harvest','Wheat');await net.drain()
        self.assertEqual(field.saved()[34],10);self.assertEqual(await mill.s.stock('WET_WHEAT'),10)
        await mill.submenu('Recipe','Wheat dryer');await mill.action('Sandbox utilities');await mill.action('Run batch')
        self.assertEqual(await mill.s.stock('WET_WHEAT'),0)
        await mill.step(3600);await mill.catchup()
        self.assertEqual(await mill.s.stock('WHEAT'),8);self.assertEqual(mill.saved()[16],2)
        await mill.target(store);await mill.submenu('Select material','Wheat');await mill.action('Send 1');await net.drain()
        self.assertEqual(await store.s.stock('WHEAT'),1);self.assertEqual(await mill.s.stock('WHEAT'),7)

    async def test_every_recipe_conserves_reserved_inputs_and_completes_once(self):
        names=['Feed mill','Wheat dryer','Corn dryer','Flour mill','Dairy','Baler','Silage clamp','Digester','Packhouse','Slurry mixer']
        for name in names:
            with self.subTest(recipe=name):
                w=await World('Processor').boot();await w.submenu('Recipe',name)
                ingredients=await w.s.ingredients()
                for i in range(0,len(ingredients),2):await bag(w,**{ingredients[i]:ingredients[i+1]})
                await w.action('Sandbox utilities');await w.action('Run batch')
                out=await w.s.output();amount=await w.s.outputQty();duration=await w.s.duration()
                self.assertEqual(w.saved()[10],1)
                before=w.saved();await w.action('Run batch');self.assertEqual(before,w.saved())
                await w.boot();await w.step(int(duration*3600+300));await w.catchup()
                self.assertEqual(w.saved()[17],1);self.assertAlmostEqual(await w.s.stock(out),amount,places=3)
                await w.step(150);self.assertEqual(w.saved()[17],1)

    async def test_processor_no_power_stalls_and_diesel_is_finite(self):
        w=await World('Processor').boot();await w.submenu('Recipe','Wheat dryer');await bag(w,WET_WHEAT=10)
        await w.action('Run batch');await w.step(600)
        self.assertEqual(w.saved()[11],0)
        await bag(w,ENERGY=100,DIESEL=.1);await w.step(3600);await w.catchup()
        self.assertLess(w.saved()[11],.051);self.assertAlmostEqual(await w.s.stock('DIESEL'),0,places=5)

    async def test_processor_missing_ingredient_does_not_debit_others(self):
        w=await World('Processor').boot();await bag(w,WHEAT=6,SOYBEAN=2)
        before=w.saved();await w.action('Run batch');self.assertEqual(before,w.saved())

    async def test_slurry_digester_biogas_generator_cycle(self):
        w=await World('Processor').boot();await w.submenu('Recipe','Slurry mixer');await bag(w,MANURE=5,WATER=5,ENERGY=20)
        await w.action('Run batch');await w.step(450);await w.catchup();self.assertEqual(await w.s.stock('SLURRY'),8)
        await bag(w,SLURRY=2);await w.submenu('Recipe','Digester');await w.action('Run batch')
        self.assertEqual(w.saved()[12],9);await w.step(10800);await w.catchup()
        self.assertEqual(await w.s.stock('DIGESTATE'),8);self.assertEqual(await w.s.stock('BIOGAS'),1)
        energy=await w.s.stock('ENERGY');await w.action('Generate power')
        self.assertAlmostEqual(await w.s.stock('ENERGY'),energy+3,places=4);self.assertEqual(await w.s.stock('BIOGAS'),0)
        await w.action('Generate power');self.assertAlmostEqual(await w.s.stock('ENERGY'),energy+3,places=4)

    async def test_receiving_respects_batch_and_transfer_reservations(self):
        w=await World('Processor').boot();await bag(w,WHEAT=6,SOYBEAN=2,HAY=2)
        await w.edit(**{'14':10.0});await w.action('Run batch')
        self.assertFalse(await w.s.credit('WATER',1));self.assertEqual(await w.s.stock('WATER'),0)
        s=await World('Storage').boot();await s.edit(**{'9':10.0,str(s.s.OUT+2):10})
        self.assertFalse(await s.s.credit('WATER',1))

    async def test_service_consumes_parts(self):
        w=await World('Processor').boot();await w.edit(**{'13':95.0})
        await w.action('Service');self.assertEqual(w.saved()[13],95)
        await bag(w,PARTS=1);await w.action('Service')
        self.assertEqual(w.saved()[13],0);self.assertEqual(await w.s.stock('PARTS'),0)

    async def test_cold_storage_consumes_power_and_slows_spoilage(self):
        a=await World('Storage').boot();b=await World('Storage').boot()
        for w in [a,b]:await bag(w,MILK=100,ENERGY=10)
        await b.action('Cold storage')
        for w in [a,b]:await w.step(3600);await w.catchup()
        self.assertGreater(await b.s.stock('MILK'),await a.s.stock('MILK'))
        self.assertLess(await b.s.stock('ENERGY'),10)

    async def test_feed_mill_to_animal_and_manure_back_to_compost(self):
        net=Network();mill=await World('Processor',net).boot();pen=await World('Livestock',net).boot();comp=await World('Compost',net).boot()
        await bag(mill,WHEAT=6,SOYBEAN=2,HAY=2,ENERGY=10)
        await mill.action('Run batch');await mill.step(900);await mill.catchup()
        await pen.edit(**{'9':0.0});await mill.target(pen);await mill.action('Select material');await mill.choose('Next');await mill.choose('Feed')
        await mill.action('Send 10');await net.drain();self.assertEqual(pen.saved()[9],10)
        await pen.step(1800);await pen.catchup();await pen.action('Muck out')
        self.assertGreater(pen.saved()[18],6)
        await pen.edit(**{'18':10.0});await pen.target(comp);await pen.action('Send manure');await net.drain()
        self.assertEqual(comp.saved()[8],10)
        await comp.action('Balanced batch');self.assertAlmostEqual(comp.saved()[11],30,places=4)

    async def test_storage_retry_keeps_one_credit(self):
        net=Network();s=await World('Storage',net).boot();p=await World('Livestock',net).boot()
        await bag(s,FEED=20);await s.target(p);await s.action('Select material');await s.choose('Next');await s.choose('Feed')
        net.drop=lambda s,t,c,m:json.loads(m).get('op')=='ACK'
        await s.action('Send load');await net.drain();self.assertEqual(p.saved()[9],210)
        net.drop=lambda *a:False;await s.step(15);await net.drain()
        self.assertEqual(p.saved()[9],210);self.assertEqual(await s.s.stock('FEED'),10)

class GardenLinkTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.bridge=await World('Garden_Link',AUTO_LOAD=0).boot()
        self.garden=await World('GardenManure',ANIMALS=0).boot()
        await self.bridge.edit(**{'8':20.0})

    async def deliver(self,ack=True):
        packet=[m for m in self.bridge.link_messages if m[1]==47130][-1]
        await self.garden.event('link_message',1,packet[1],packet[2],packet[3])
        if ack:
            response=self.garden.link_messages[-1]
            await self.bridge.event('link_message',1,response[1],response[2],response[3])

    async def test_current_garden_producer_api_consumes_finite_manure(self):
        await self.bridge.action('Load Garden 10');await self.deliver()
        self.assertEqual(self.bridge.saved()[8],10);self.assertEqual(self.bridge.saved()[9],0)
        self.assertEqual(self.garden.s.S[2],10)

    async def test_lost_link_ack_reset_and_retry_do_not_duplicate(self):
        await self.bridge.action('Load Garden 10');await self.deliver(False)
        await self.bridge.boot();await self.garden.boot();await self.deliver()
        self.assertEqual(self.garden.s.S[2],10);self.assertEqual(self.bridge.saved()[12],10)

    async def test_child_or_wrong_transaction_ack_ignored(self):
        await self.bridge.action('Load Garden 10')
        msg=json.dumps({'v':1,'op':'ACK','seq':1})
        await self.bridge.event('link_message',2,47131,msg,lummao.Key(self.bridge.saved()[11]))
        await self.bridge.event('link_message',1,47131,msg,NULL)
        self.assertEqual(self.bridge.saved()[9],10)

    async def test_default_auto_bridge_forwards_without_competing_touch_ui(self):
        w=await World('Garden_Link').boot();await w.edit(**{'8':10.0});await w.step(15)
        self.assertEqual(w.saved()[8],0);self.assertEqual(w.saved()[9],10)
        self.assertTrue(any(m[1]==47130 for m in w.link_messages));await w.touch();self.assertFalse(w.dialogs)

class GroupWorkerTests(unittest.IsolatedAsyncioTestCase):
    async def test_group_worker_can_tend_but_not_restock_or_configure(self):
        w=World('Field',GROUP_WORK=1);w.group=lummao.Key('55555555-5555-4555-8555-555555555555');w.members={OTHER};await w.boot()
        await w.touch(OTHER);self.assertIn('Plow',w.dialogs[-1][2]);self.assertNotIn('Settings',w.dialogs[-1][2])
        await w.choose('Plow',who=OTHER);self.assertEqual(w.saved()[9],1)
        await w.choose('Refill supplies',who=OTHER);self.assertEqual(w.saved()[28],48)

    async def test_null_group_does_not_grant_access(self):
        w=await World('Field',GROUP_WORK=1).boot();w.members={OTHER}
        await w.touch(OTHER);self.assertEqual(w.dialogs,[])
