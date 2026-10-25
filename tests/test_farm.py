import json
import unittest
import uuid
from pathlib import Path

import lummao
from world import World, Network, OWNER, OTHER, ROOT

class CompileTests(unittest.TestCase):
    def test_all_generated_scripts_compile(self):
        for path in (ROOT / 'lsl').glob('*.lsl'):
            with self.subTest(script=path.name): lummao.compile_script_file(str(path))

    def test_generated_sources_current(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location('build', ROOT / 'tools/build.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        module.build(check=True)

class PersistenceTests(unittest.IsolatedAsyncioTestCase):
    async def test_invalid_fresh_configuration_never_writes(self):
        w=await World('Livestock',SPECIES='Typo').boot()
        self.assertTrue(w.s.fault)
        self.assertEqual(w.store,{})

    async def test_invalid_crop_index_locks_without_render_exception(self):
        w=await World().boot();data=w.saved();data[8]=99
        raw=json.dumps(data);w.store[w.s.DATA]=raw
        await w.boot()
        self.assertTrue(w.s.fault);self.assertEqual(w.store[w.s.DATA],raw)

    async def test_all_menus_fit_viewer_limits(self):
        for module in ['Field','Livestock','Compost','Garden_Applicator']:
            w=await World(module).boot()
            for page in ['main','settings','target']:
                await w.s.show(page)
            if module=='Field':
                for page in ['plant','storage','clear','soil','utility']:await w.s.show(page)
            await w.submenu('Settings','Diagnostics')
            self.assertTrue(any('Free script memory' in x for x in w.chat))

    async def test_starter_records_are_valid_and_reset_stable(self):
        for name in ['Field','Livestock','Compost','Garden_Applicator']:
            with self.subTest(module=name):
                w = await World(name).boot()
                self.assertTrue(await w.s.validBase(w.s.S))
                self.assertTrue(await w.s.validSpecific(w.s.S))
                before = w.saved()
                await w.boot()
                self.assertEqual(before, w.saved())
                self.assertFalse(w.s.fault)

    async def test_invalid_records_are_preserved(self):
        for bad in ['broken', '[99]', '{"not":"a state"}']:
            w = World()
            w.store['dreamfarm:field:v1'] = bad
            await w.boot()
            self.assertTrue(w.s.fault)
            self.assertEqual(w.store['dreamfarm:field:v1'], bad)

    async def test_negative_resource_and_wrong_type_rejected(self):
        for value in [-1, 'bad', None, 1000001]:
            w = await World().boot()
            data = w.saved(); data[25] = value
            w.store[w.s.DATA] = json.dumps(data)
            await w.boot()
            self.assertTrue(w.s.fault)
            self.assertEqual(w.saved()[25], value)

    async def test_owner_change_preserves_and_locks(self):
        w = await World().boot(); before = w.saved()
        w.owner = OTHER
        await w.boot()
        self.assertTrue(w.s.fault)
        self.assertEqual(before, w.saved())

    async def test_write_failure_rolls_back_and_blocks_further_actions(self):
        w = await World().boot(); before = w.saved()
        memory_before = list(w.s.S)
        w.fail_writes = True
        await w.action('Plow')
        self.assertTrue(w.s.fault)
        self.assertEqual(before,w.saved())
        self.assertEqual(memory_before,list(w.s.S))
        w.fail_writes = False
        await w.boot(); await w.action('Plow')
        self.assertEqual(w.saved()[9],1)

    async def test_pause_and_resume_discard_paused_elapsed(self):
        w = await World().boot()
        await w.submenu('Settings','Pause')
        await w.step(10000)
        self.assertEqual(w.saved()[6],0)
        await w.submenu('Settings','Resume')
        await w.step(150)
        self.assertAlmostEqual(w.saved()[6],1/24,places=5)

    async def test_fixed_step_catchup_matches_frequent_events(self):
        a = await World().boot(); b = await World().boot()
        await a.step(3600); await a.catchup()
        for _ in range(24): await b.step(150)
        for i in [6,12,13,19]: self.assertAlmostEqual(a.saved()[i], b.saved()[i], places=4)

    async def test_large_absence_records_frozen_excess_and_bounds_work(self):
        w = await World().boot()
        await w.step(90000)
        self.assertEqual(w.saved()[7],3600)
        self.assertAlmostEqual(w.saved()[6],8/24,places=4)
        self.assertGreater(w.now-w.saved()[3],150)

    async def test_speed_change_settles_old_rate(self):
        w = await World().boot(); w.now += 150
        await w.submenu('Settings','Demo x60')
        self.assertAlmostEqual(w.saved()[6],1/24,places=4)
        await w.step(5)
        self.assertAlmostEqual(w.saved()[6],1/8,places=4)

    async def test_clock_rollback_locks_without_saving(self):
        w = await World().boot(); before=w.saved()
        w.now -= 5; await w.event('timer')
        self.assertTrue(w.s.fault); self.assertEqual(before,w.saved())

    async def test_strangers_stale_wrong_channel_and_out_of_range_dialogs(self):
        w = await World().boot()
        await w.touch(OTHER); self.assertEqual(w.dialogs,[])
        await w.touch()
        await w.choose('Plow',who=OTHER)
        await w.choose('Plow',channel=-99)
        self.assertEqual(w.saved()[9],0)
        w.positions[OWNER] = lummao.Vector((100.,0.,0.))
        await w.choose('Plow'); self.assertEqual(w.saved()[9],0)
        w.positions[OWNER] = lummao.Vector((1.,0.,0.))
        w.now += 46
        await w.choose('Plow'); self.assertEqual(w.saved()[9],0)

class FieldTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self): self.w = await World().boot()

    async def plant(self,crop='Wheat'):
        await self.w.action('Plow')
        await self.w.submenu('Plant',crop)

    async def test_plant_requires_tillage_and_debits_seed_and_fuel(self):
        await self.w.submenu('Plant','Corn')
        self.assertEqual(self.w.saved()[8],0)
        await self.plant('Corn')
        self.assertEqual(self.w.saved()[8],2)
        self.assertEqual(self.w.saved()[24],11)
        self.assertAlmostEqual(self.w.saved()[28],47.5)

    async def test_empty_seed_or_fuel_blocks_action(self):
        await self.w.edit(**{'24':0})
        await self.plant()
        self.assertEqual(self.w.saved()[8],0)
        await self.w.edit(**{'24':10,'28':0.0})
        await self.w.submenu('Plant','Corn')
        self.assertEqual(self.w.saved()[8],0)

    async def test_growth_changes_with_temperature_water_and_soil(self):
        await self.plant()
        other=await World().boot();await other.action('Plow');await other.submenu('Plant','Wheat')
        await other.edit(**{'12':0.0})
        await self.w.step(150);await other.step(150)
        self.assertGreater(self.w.saved()[10],other.saved()[10])
        self.assertLess(other.saved()[11],100)
        self.assertNotEqual(await self.w.s.temperature(30.0),await self.w.s.temperature(90.0))

    async def test_waterlogging_and_frost_damage(self):
        await self.plant()
        await self.w.edit(**{'12':100.0,'6':95.0})
        await self.w.step(150)
        self.assertLess(self.w.saved()[11],100)

    async def test_irrigation_conserves_tank_water(self):
        await self.w.edit(**{'12':10.0,'25':0.3,'31':1})
        await self.w.step(150)
        self.assertEqual(self.w.saved()[25],0)
        self.assertLess(self.w.saved()[12],11)

    async def test_greenhouse_power_is_consumed_and_outage_falls_back(self):
        await self.plant()
        await self.w.edit(**{'30':1,'33':1,'32':1.0})
        await self.w.step(150)
        self.assertLess(self.w.saved()[32],1)
        await self.w.edit(**{'32':0.0})
        await self.w.step(150)
        self.assertEqual(self.w.saved()[32],0)

    async def test_single_harvest_atomic_and_no_repeated_credit(self):
        await self.plant()
        await self.w.edit(**{'10':300.0})
        await self.w.action('Harvest')
        saved=self.w.saved()
        self.assertEqual(saved[8],0);self.assertEqual(saved[34],30)
        self.assertEqual(saved[24],13);self.assertEqual(saved[40],9)
        await self.w.action('Harvest');self.assertEqual(saved,self.w.saved())
        await self.w.boot();self.assertEqual(saved,self.w.saved())

    async def test_storage_full_keeps_crop_and_fuel(self):
        await self.plant();await self.w.edit(**{'10':300.0,'34':999990.0})
        before=self.w.saved();await self.w.action('Harvest')
        self.assertEqual(before,self.w.saved())

    async def test_clear_needs_confirmation_preserves_stock(self):
        await self.plant();await self.w.edit(**{'34':10.0})
        await self.w.submenu('Soil care','Clear crop')
        self.assertEqual(self.w.saved()[8],1)
        await self.w.choose('Confirm clear')
        self.assertEqual(self.w.saved()[8],0);self.assertEqual(self.w.saved()[34],10)

    async def test_mature_compost_is_consumed_and_changes_soil(self):
        await self.w.edit(**{'27':2.0})
        await self.w.submenu('Soil care','Compost')
        self.assertEqual(self.w.saved()[27],0)
        self.assertEqual(self.w.saved()[13],80)
        self.assertEqual(self.w.saved()[17],4.5)

    async def test_spoilage_and_storage_use(self):
        await self.w.edit(**{'34':10.0,'37':10.0})
        await self.w.step(150)
        self.assertLess(self.w.saved()[37],self.w.saved()[34])
        self.assertGreater(self.w.saved()[42],0)
        await self.w.submenu('Utilities','Storage');await self.w.choose('Wheat')
        self.assertLess(self.w.saved()[34],9)

    async def test_repeat_crop_disease_penalty(self):
        await self.w.edit(**{'23':1})
        await self.plant()
        self.assertEqual(self.w.saved()[21],20)

    async def test_dead_crop_never_grows_or_harvests(self):
        await self.plant();await self.w.edit(**{'11':0.0,'10':300.0})
        await self.w.action('Harvest')
        self.assertEqual(self.w.saved()[34],0)
        await self.w.step(150);self.assertEqual(self.w.saved()[11],0)

    async def test_all_crops_reach_harvest_under_maintained_conditions(self):
        for crop in ['Wheat','Corn','Soybean','Potato','Sunflower','Grass']:
            with self.subTest(crop=crop):
                w=await World().boot()
                await w.action('Plow');await w.submenu('Plant',crop)
                # Isolate thermal progression using maintained greenhouse/soil inputs.
                # All advancement still runs the LSL fixed-step model and harvest UI.
                for _ in range(160):
                    await w.edit(**{'12':60.0,'13':65.0,'14':65.0,'15':65.0,'19':0.0,'20':0.0,'21':0.0,'30':1,'33':1,'32':100.0})
                    await w.step(3600);await w.catchup()
                    if await w.s.stage()==4:break
                self.assertEqual(await w.s.stage(),4)
                await w.action('Harvest')
                self.assertEqual(w.saved()[41],1)


class LivestockTests(unittest.IsolatedAsyncioTestCase):
    async def test_feed_water_production_and_manure_mass(self):
        w=await World('Livestock').boot()
        await w.step(3600);await w.catchup()
        self.assertAlmostEqual(w.saved()[9],180,places=3)
        self.assertAlmostEqual(w.saved()[10],440,places=3)
        self.assertAlmostEqual(w.saved()[17],13,places=3)
        self.assertGreater(w.saved()[19],0)
        await w.action('Muck out')
        self.assertEqual(w.saved()[17],0)
        self.assertAlmostEqual(w.saved()[18],13,places=3)
        self.assertEqual(w.saved()[26],2)

    async def test_hunger_thirst_and_death_stop_production(self):
        w=await World('Livestock').boot();await w.edit(**{'9':0.0,'10':0.0,'14':0.0})
        await w.step(3600);await w.catchup()
        self.assertEqual(w.saved()[17],0);self.assertEqual(w.saved()[19],0)
        await w.action('Treat');self.assertEqual(w.saved()[14],0)

    async def test_pregnancy_and_birth_per_species(self):
        for species,gest,litter in [('Cattle',283,1),('Chicken',21,4),('Sheep',147,2),('Pig',114,8)]:
            with self.subTest(species=species):
                w=await World('Livestock',SPECIES=species).boot()
                await w.action('Breed');self.assertEqual(w.saved()[20],0)
                await w.edit(**{'20':gest-0.01})
                await w.step(150)
                self.assertEqual(w.saved()[21],litter)
                self.assertEqual(w.saved()[20],-1)

    async def test_species_change_locks_existing_record(self):
        w=await World('Livestock').boot();before=w.saved()
        w.config['SPECIES']='Pig';await w.boot()
        self.assertTrue(w.s.fault);self.assertEqual(before,w.saved())

class CompostTests(unittest.IsolatedAsyncioTestCase):
    async def test_no_fresh_manure_exported_as_compost(self):
        w=await World('Compost').boot();await w.edit(**{'8':20.0})
        await w.action('Send compost')
        self.assertEqual(w.saved()[18],0);self.assertEqual(w.saved()[w.s.OUT+2],0)

    async def test_batch_consumes_recipe_and_requires_management(self):
        w=await World('Compost').boot();await w.edit(**{'8':10.0})
        await w.action('Start batch')
        self.assertEqual(w.saved()[8],0);self.assertEqual(w.saved()[9],15)
        self.assertEqual(w.saved()[10],15);self.assertEqual(w.saved()[17],1)
        await w.edit(**{'12':0.0})
        await w.step(3600);await w.catchup()
        self.assertEqual(w.saved()[15],0)
        self.assertEqual(w.saved()[18],0)

    async def test_completes_active_and_curing_stages_no_double_completion(self):
        w=await World('Compost').boot();await w.edit(**{'8':10.0})
        await w.action('Start batch')
        # Actual numerical model, maintained every simulated day.
        for _ in range(36):
            await w.edit(**{'12':55.0,'13':100.0})
            await w.step(3600);await w.catchup()
            if w.saved()[17]==0: break
        self.assertEqual(w.saved()[17],0)
        self.assertAlmostEqual(w.saved()[18],8.25,places=3)
        await w.step(3600);await w.catchup()
        self.assertAlmostEqual(w.saved()[18],8.25,places=3)

    async def test_overwatering_slows_processing(self):
        w=await World('Compost').boot();await w.edit(**{'8':10.0})
        await w.action('Start batch');await w.edit(**{'12':100.0})
        await w.step(3600);await w.catchup()
        self.assertEqual(w.saved()[15],0)

class TransferTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.net=Network()
        self.barn=await World('Livestock',self.net).boot()
        self.bin=await World('Compost',self.net).boot()
        await self.barn.edit(**{'18':30.0})
        await self.barn.target(self.bin)

    async def send(self):
        await self.barn.action('Send manure');await self.net.drain()

    async def test_success_debit_credit_and_clear_pending(self):
        await self.send()
        self.assertEqual(self.barn.saved()[18],20)
        self.assertEqual(self.bin.saved()[8],10)
        self.assertEqual(self.barn.saved()[29],0)

    async def test_lost_ack_reset_and_retry_never_duplicate_credit(self):
        self.net.drop=lambda s,t,c,m: json.loads(m).get('op')=='ACK'
        await self.send()
        self.assertEqual(self.bin.saved()[8],10)
        self.assertEqual(self.barn.saved()[29],10)
        await self.bin.boot();await self.barn.boot()
        self.net.drop=lambda *a:False
        await self.barn.step(15);await self.net.drain()
        self.assertEqual(self.bin.saved()[8],10)
        self.assertEqual(self.barn.saved()[18],20)
        self.assertEqual(self.barn.saved()[29],0)

    async def test_lost_request_keeps_durable_reserved_load(self):
        self.net.drop=lambda *a:True
        await self.send()
        self.assertEqual(self.bin.saved()[8],0)
        self.assertEqual(self.barn.saved()[29],10)
        await self.barn.action('Send manure')
        self.assertEqual(self.barn.saved()[18],20)
        self.net.drop=lambda *a:False
        await self.barn.step(15);await self.net.drain()
        self.assertEqual(self.bin.saved()[8],10)

    async def test_receiver_write_failure_no_ack_then_recovers(self):
        self.bin.fail_writes=True
        await self.send()
        self.assertTrue(self.bin.s.fault)
        self.assertEqual(self.bin.saved()[8],0)
        self.assertEqual(self.barn.saved()[29],10)
        self.bin.fail_writes=False;await self.bin.boot()
        await self.barn.step(15);await self.net.drain()
        self.assertEqual(self.bin.saved()[8],10)

    async def test_sender_write_failure_sends_nothing(self):
        self.barn.fail_writes=True
        await self.send()
        self.assertEqual(self.bin.saved()[8],0)
        self.assertEqual(self.barn.saved()[18],30)

    async def test_foreign_owner_or_distance_blocks_transfer(self):
        self.bin.owner=OTHER
        await self.send();self.assertEqual(self.barn.saved()[18],30)
        self.bin.owner=OWNER;self.bin.position=lummao.Vector((20.,0.,0.))
        await self.send();self.assertEqual(self.barn.saved()[18],30)

    async def test_bad_packets_do_not_credit(self):
        packet={'v':1,'op':'LOAD','target':str(self.bin.key),'stream':str(uuid.uuid4()),'seq':1,'qty':10,'kind':'MANURE'}
        for key,value in [('v',2),('qty',-1),('qty',1.5),('qty','10'),('seq',0),('target',str(self.barn.key)),('kind','MONEY')]:
            altered=dict(packet);altered[key]=value
            await self.bin.event('listen',self.bin.s.NET,'Object',self.barn.key,json.dumps(altered))
        self.assertEqual(self.bin.saved()[8],0)

    async def test_same_sequence_changed_payload_is_rejected(self):
        await self.send()
        load=next(json.loads(p[3]) for p in self.net.packets if json.loads(p[3]).get('op')=='LOAD')
        load['qty']=20
        await self.bin.event('listen',self.bin.s.NET,'Object',self.barn.key,json.dumps(load))
        self.assertEqual(self.bin.saved()[8],10)

    async def test_receipt_capacity_never_evicts_old_receipts(self):
        for seq in range(9):
            msg={'v':1,'op':'LOAD','target':str(self.bin.key),'stream':str(uuid.uuid4()),'seq':1,'qty':1,'kind':'MANURE'}
            await self.bin.event('listen',self.bin.s.NET,'Object',self.barn.key,json.dumps(msg))
        self.assertEqual(self.bin.saved()[8],8)
        self.assertEqual(len(self.bin.saved()),self.bin.s.BASE+32)

    async def test_compost_to_field_and_applicator(self):
        field=await World('Field',self.net).boot()
        app=await World('Garden_Applicator',self.net).boot()
        await self.bin.edit(**{'18':6.0})
        await self.bin.target(field);await self.bin.action('Send compost');await self.net.drain()
        self.assertEqual(field.saved()[27],2)
        await self.bin.target(app);await self.bin.step(15)
        await self.bin.action('Send compost');await self.net.drain()
        self.assertEqual(app.saved()[8],2)
        self.assertEqual(self.bin.saved()[18],2)

class GardenIntegrationTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.net=Network()
        self.app=await World('Garden_Applicator',self.net).boot()
        self.garden=await World('GardenReference',self.net).boot()
        # Initial fertility below the existing Botany MANURE threshold.
        self.garden.s.S[6]=30.0
        await self.garden.s.save(list(self.garden.s.S))
        await self.app.edit(**{'8':6.0})
        await self.app.target(self.garden)

    async def test_actual_garden_botany_accepts_application(self):
        await self.app.action('Apply compost');await self.net.drain()
        self.assertEqual(self.app.saved()[8],4)
        self.assertEqual(self.app.saved()[10],0)
        self.assertEqual(self.app.saved()[14],1)
        self.assertAlmostEqual(self.garden.s.S[6],55,places=4)

    async def test_garden_ack_loss_retry_same_request_once(self):
        self.net.drop=lambda s,t,c,m: s==self.garden.key and json.loads(m).get('op')=='ACK'
        await self.app.action('Apply compost');await self.net.drain()
        self.assertEqual(self.app.saved()[10],2)
        await self.garden.boot();await self.app.boot()
        self.net.drop=lambda *a:False
        self.garden.now+=2;await self.app.step(2);await self.net.drain()
        self.assertAlmostEqual(self.garden.s.S[6],55,delta=.1)
        self.assertEqual(self.app.saved()[10],0)
        self.assertEqual(self.app.saved()[14],1)

    async def test_pending_garden_request_retries_immediately_on_boot(self):
        self.net.drop=lambda *a:True
        await self.app.action('Apply compost');self.assertEqual(self.app.saved()[10],2)
        self.app.now+=2;self.garden.now+=2
        self.net.drop=lambda *a:False
        await self.app.boot();await self.net.drain()
        self.assertEqual(self.app.saved()[10],0)
        self.assertEqual(self.app.saved()[14],1)

    async def test_timeout_never_automatically_refunds(self):
        self.net.drop=lambda *a:True
        await self.app.action('Apply compost');await self.net.drain()
        await self.app.step(20)
        self.assertEqual(self.app.saved()[8],4)
        self.assertEqual(self.app.saved()[10],2)
        await self.app.action('Apply compost');self.assertEqual(self.app.saved()[8],4)
        await self.app.action('Resolve timeout');await self.app.choose('Confirm discard')
        self.assertEqual(self.app.saved()[8],4);self.assertEqual(self.app.saved()[10],0)

    async def test_garden_rejection_holds_and_fresh_manure_is_rejected(self):
        self.garden.s.S[6]=90.0;await self.garden.s.save(list(self.garden.s.S))
        await self.app.action('Apply compost');await self.net.drain()
        self.assertEqual(self.app.saved()[10],2)
        self.assertFalse(await self.app.s.credit('MANURE',10))

class VisualTests(unittest.IsolatedAsyncioTestCase):
    async def test_only_named_stage_children_are_changed(self):
        w=await World('Visuals').boot()
        msg=json.dumps({'kind':'FIELD','stage':4,'fault':0})
        await w.event('link_message',1,48100,msg,lummao.Key(''))
        self.assertEqual(w.alpha,{2:0,3:0,4:0,5:0,6:1,7:0})
        await w.event('link_message',2,48100,json.dumps({'kind':'FIELD','stage':1}),lummao.Key(''))
        self.assertEqual(w.alpha[6],1)

if __name__=='__main__': unittest.main()
