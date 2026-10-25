import json
import unittest
import lummao
from world import World,Network,OWNER,OTHER,NULL,ZERO
from test_expansion import bag
from test_equipment import key

class SpreadingTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.net=Network();self.m=await World('Machine',self.net).boot();self.f=await World('Field',self.net).boot()
        await self.m.target(self.f);await self.m.submenu('Implement','Spread');await self.m.edit(**{'24':100.0})
        await self.m.action('Engine');await self.m.submenu('Cab controls','PTO');await self.m.action('Lower or raise')

    def position(self,cell):
        self.m.position=lummao.Vector((-8.75+cell%8*2.5,-8.75+cell//8*2.5,0.))
        self.m.velocity=lummao.Vector((1.,0.,0.))
        for w in [self.m,self.f]:w.positions[OWNER]=self.m.position

    async def drive(self,cell):
        self.position(cell);self.m.now+=1;self.f.now=self.m.now
        await self.m.event('link_message',1,48200,json.dumps(dict(v=1,actor=str(OWNER),load=1000)),key())
        await self.net.drain()

    async def test_each_cell_debits_one_dose_and_finishes_once(self):
        for cell in range(64):await self.drive(cell)
        self.assertEqual(self.m.saved()[24],36);self.assertEqual(self.m.saved()[16],64)
        self.assertEqual(self.m.saved()[18],0);self.assertEqual(self.f.saved()[49],[1]*64)
        self.assertGreater(self.f.saved()[13],65)
        await self.drive(63);self.assertEqual(self.m.saved()[24],36)
        self.assertTrue(await self.m.s.validSpecific(self.m.s.S));self.assertTrue(await self.f.s.validSpecific(self.f.s.S))

    async def test_same_cell_cannot_spend_again_in_same_job(self):
        await self.drive(0);await self.drive(0)
        self.assertEqual(self.m.saved()[24],99);self.assertEqual(self.m.saved()[16],1)
        self.assertEqual(self.f.saved()[49][0],1)

    async def test_lost_ack_moving_receiver_retry_marks_original_cell(self):
        self.net.drop=lambda s,t,c,m:json.loads(m).get('op')=='ACK'
        await self.drive(0);self.assertEqual(self.m.saved()[self.m.s.OUT+2],1)
        self.assertEqual(self.f.saved()[49][0],1);self.position(1)
        self.net.drop=lambda *a:False;await self.m.step(15);await self.net.drain()
        self.assertEqual(self.m.saved()[16],1);self.assertEqual(self.m.saved()[30],-1)
        self.assertEqual(self.f.saved()[49][0],1);self.assertEqual(self.f.saved()[49][1],0)

    async def test_lost_load_waits_until_machine_returns_to_bound_cell(self):
        self.net.drop=lambda s,t,c,m:json.loads(m).get('op')=='LOAD'
        await self.drive(0);self.position(1);self.net.drop=lambda *a:False
        await self.m.step(15);await self.net.drain()
        self.assertEqual(sum(self.f.saved()[49]),0);self.assertEqual(self.m.saved()[self.m.s.OUT+2],1)
        self.position(0);await self.m.step(15);await self.net.drain()
        self.assertEqual(self.f.saved()[49][0],1);self.assertEqual(self.m.saved()[24],99)

    async def test_reset_both_ends_keeps_one_dose_and_stops_engine(self):
        self.net.drop=lambda s,t,c,m:json.loads(m).get('op')=='ACK'
        await self.drive(0);await self.f.boot();await self.m.boot()
        self.net.drop=lambda *a:False;await self.m.step(15);await self.net.drain()
        self.assertEqual(self.f.saved()[49][0],1);self.assertEqual(self.m.saved()[24],99)
        self.assertEqual(self.m.saved()[9],0);self.assertEqual(self.m.saved()[19],0)
        self.assertEqual(self.m.saved()[16],1)

    async def test_sender_write_failure_sends_no_dose_or_drive_permission(self):
        self.m.fail_writes=True;await self.drive(0)
        self.assertEqual(self.m.saved()[24],100);self.assertEqual(sum(self.f.saved()[49]),0)
        reply=json.loads([m for m in self.m.link_messages if m[1]==48201][-1][2]);self.assertEqual(reply['run'],0)

    async def test_receiver_write_failure_holds_source_reservation_then_recovers(self):
        self.f.fail_writes=True;await self.drive(0)
        self.assertEqual(sum(self.f.saved()[49]),0);self.assertEqual(self.m.saved()[self.m.s.OUT+2],1)
        self.f.fail_writes=False;await self.f.boot();await self.m.step(15);await self.net.drain()
        self.assertEqual(self.f.saved()[49][0],1);self.assertEqual(self.m.saved()[self.m.s.OUT+2],0)

    async def test_job_material_and_dose_cannot_change_while_pending(self):
        self.net.drop=lambda s,t,c,m:json.loads(m).get('op')=='ACK';await self.drive(0)
        job=self.m.saved()[12];await self.m.action('New job');self.assertEqual(self.m.saved()[12],job)
        await self.m.submenu('Spreader setup','Dose 4');self.assertEqual(self.m.saved()[23],1)
        await self.m.submenu('Implement','Plow');self.assertEqual(self.m.saved()[10],4)

    async def test_pto_hydraulics_hitch_and_motion_gate_application(self):
        for slot in ['19','20','21']:
            await self.m.edit(**{slot:0});await self.drive(0);self.assertEqual(sum(self.f.saved()[49]),0)
            await self.m.edit(**{slot:1})
        self.position(0);self.m.velocity=ZERO
        await self.m.event('link_message',1,48200,json.dumps(dict(v=1,actor=str(OWNER),load=0)),key());await self.net.drain()
        self.assertEqual(sum(self.f.saved()[49]),0)
        await self.drive(0);self.assertEqual(self.f.saved()[49][0],1)

    async def test_overapplication_causes_stress_and_runoff_once(self):
        await self.m.submenu('Spreader setup','Dose 4');await self.m.action('Lower or raise')
        await self.f.edit(**{'8':1,'12':95.0});await self.drive(0)
        health=self.f.saved()[11];await self.m.action('New job');await self.m.action('Lower or raise');await self.drive(0)
        self.assertEqual(self.f.saved()[49][0],8);self.assertLess(self.f.saved()[11],health);self.assertGreater(self.f.saved()[47],0)
        after=self.f.saved();await self.drive(0);self.assertEqual(self.f.saved(),after)

    async def test_far_corner_spreading_allowed_but_ordinary_loading_stays_eight_metres(self):
        await self.drive(0);self.assertEqual(self.f.saved()[49][0],1)
        source=await World('Storage',self.net).boot();await bag(source,COMPOST=10)
        source.position=self.m.position;source.positions[OWNER]=source.position
        await source.target(self.f);await source.action('Select material');await source.choose('Next');await source.choose('Compost');await source.action('Send load');await self.net.drain()
        self.assertEqual(self.f.saved()[27],0);self.assertEqual(await source.s.stock('COMPOST'),10)

    async def test_wrong_cell_invalid_material_or_foreign_owner_never_applied(self):
        self.position(1)
        for material in ['SPREAD|MANURE|0','SPREAD|MANURE|01','SPREAD|WATER|1']:
            p=dict(v=1,op='LOAD',target=str(self.f.key),stream=str(key()),seq=1,qty=1,kind=material)
            await self.f.event('listen',-163847025,'Machine',self.m.key,json.dumps(p))
        self.m.owner=OTHER;await self.drive(1);self.assertEqual(sum(self.f.saved()[49]),0)

    async def test_rotated_field_uses_actual_local_cell(self):
        self.f.rotation=lummao.Quaternion((0.,0.,0.70710678,0.70710678))
        self.m.position=lummao.Vector((8.75,-8.75,0.));self.m.velocity=lummao.Vector((1.,0.,0.))
        for w in [self.m,self.f]:w.positions[OWNER]=self.m.position
        await self.m.event('link_message',1,48200,json.dumps(dict(v=1,actor=str(OWNER),load=1000)),key());await self.net.drain()
        self.assertEqual(self.f.saved()[49][0],1);self.assertEqual(sum(self.f.saved()[49]),1)

    async def test_pending_spread_reserves_capacity_for_reloads(self):
        await self.m.edit(**{'24':500.0});self.net.drop=lambda s,t,c,m:json.loads(m).get('op')=='ACK'
        await self.drive(0);self.assertEqual(self.m.saved()[24],499)
        self.assertFalse(await self.m.s.credit('MANURE',1))
        self.net.drop=lambda *a:False;await self.m.step(15);await self.net.drain()
        self.assertTrue(await self.m.s.credit('MANURE',1))

class OperationsTests(unittest.IsolatedAsyncioTestCase):
    async def test_new_module_state_and_menus(self):
        for module in ['ManureStore','Pasture']:
            w=await World(module).boot();self.assertFalse(w.s.fault)
            self.assertTrue(await w.s.validSpecific(w.s.S))
            for p in ['main','settings','material']:await w.s.show(p)
            before=w.saved();await w.boot();self.assertEqual(before,w.saved())

    async def test_separation_requires_energy_and_agitation_and_conserves_material(self):
        w=await World('ManureStore').boot();await bag(w,SLURRY=10)
        await w.action('Separate 10');self.assertEqual(await w.s.stock('SLURRY'),10)
        await w.action('Agitate');await w.action('Separate 10')
        self.assertEqual(await w.s.stock('SLURRY'),0);self.assertEqual(await w.s.stock('MANURE'),3);self.assertEqual(await w.s.stock('WATER'),7)
        self.assertEqual(await w.s.stock('ENERGY'),18)
        await w.action('Separate 10');self.assertEqual(await w.s.stock('MANURE'),3)

    async def test_manure_store_leak_and_repair_do_not_restore_lost_material(self):
        w=await World('ManureStore').boot();await bag(w,SLURRY=100,WATER=100);await w.edit(**{'11':100.0})
        await w.step(3600);await w.catchup()
        remaining=await w.s.stock('SLURRY')+await w.s.stock('WATER')
        self.assertLess(remaining,200);self.assertAlmostEqual(remaining+w.saved()[12],200,places=3)
        loss=w.saved()[12];await w.action('Repair liner');self.assertEqual(w.saved()[11],0);self.assertEqual(w.saved()[12],loss)
        self.assertEqual(await w.s.stock('PARTS'),4)

    async def test_rain_overflow_respects_pending_capacity(self):
        net=Network();w=await World('ManureStore',net).boot();c=await World('Compost',net).boot()
        await bag(w,MANURE=20);await w.edit(**{'9':45.0,'6':1.0});await w.target(c)
        net.drop=lambda s,t,ch,m:json.loads(m).get('op')=='ACK'
        await w.action('Send 10');await net.drain()
        self.assertGreater(await w.s.farmRain(1.0),0)
        await w.action('Cover');await w.step(150)
        self.assertEqual(await w.s.totalStock(),35);self.assertEqual(w.saved()[w.s.OUT+2],10);self.assertGreater(w.saved()[12],0)
        self.assertFalse(await w.s.credit('MANURE',1))

    async def test_manure_store_to_compost_finite_load(self):
        net=Network();s=await World('ManureStore',net).boot();c=await World('Compost',net).boot()
        await bag(s,MANURE=10);await s.target(c);await s.action('Send 10');await net.drain()
        self.assertEqual(await s.s.stock('MANURE'),0);self.assertEqual(c.saved()[8],10)

    async def test_pasture_grazing_lost_ack_does_not_double_feed(self):
        net=Network();p=await World('Pasture',net).boot();h=await World('Herd',net).boot();await p.target(h)
        net.drop=lambda s,t,c,m:json.loads(m).get('op')=='ACK'
        await p.action('Grazing gate');await net.drain()
        self.assertEqual(p.saved()[9],580);self.assertEqual(await h.s.stock('GRASS'),20)
        await p.boot();await net.drain();self.assertEqual(await h.s.stock('GRASS'),20)
        net.drop=lambda *a:False;await p.step(15);await net.drain();self.assertEqual(p.saved()[9],580)

    async def test_pasture_protects_residual_and_low_cut_needs_confirmation(self):
        net=Network();p=await World('Pasture',net).boot();h=await World('Herd',net).boot();await p.target(h)
        await p.edit(**{'9':119.0});await p.action('Grazing gate');await net.drain();self.assertEqual(await h.s.stock('GRASS'),0)
        await p.action('Mow 50');self.assertEqual(p.saved()[9],119)
        await p.action('Low cut');self.assertEqual(p.saved()[9],119)
        await p.choose('Confirm low cut');self.assertEqual(p.saved()[9],69);self.assertEqual(await p.s.stock('GRASS'),50)
        self.assertLess(p.saved()[10],100)

    async def test_pasture_regrowth_drought_and_reseeding_consume_resources(self):
        moist=await World('Pasture').boot();dry=await World('Pasture').boot();await dry.edit(**{'11':0.0})
        await moist.step(150);await dry.step(150)
        self.assertGreater(moist.saved()[9],600);self.assertLess(dry.saved()[9],600)
        await dry.edit(**{'9':0.0});await dry.action('Reseed');self.assertEqual(await dry.s.stock('SEED'),1);self.assertEqual(dry.saved()[9],25)
        before=await dry.s.stock('WATER');await dry.action('Water pasture');self.assertEqual(await dry.s.stock('WATER'),before-20)

    async def test_pasture_mow_to_processor_baler_chain(self):
        net=Network();p=await World('Pasture',net).boot();b=await World('Processor',net).boot()
        await p.action('Mow 50');await p.target(b);await p.action('Send cut grass');await net.drain()
        self.assertEqual(await b.s.stock('GRASS'),20);self.assertEqual(await p.s.stock('GRASS'),30)
        await b.submenu('Recipe','Baler');await bag(b,ENERGY=10);await b.action('Run batch');await b.step(1800);await b.catchup()
        self.assertEqual(await b.s.stock('HAY'),6)

class CabAndMigrationTests(unittest.IsolatedAsyncioTestCase):
    async def test_machine_v1_migration_preserves_inventory_identity_and_receipts(self):
        w=await World('Machine').boot();old=w.saved();old[0]=1;del old[19:34]
        old += [str(key()),1,10,'DIESEL'];old[8]=37.0
        w.store[w.s.DATA]=json.dumps(old);await w.boot()
        self.assertEqual(w.saved()[0],2);self.assertEqual(w.saved()[8],37);self.assertEqual(w.saved()[34:],old[19:])
        self.assertEqual(w.saved()[33],100)

    async def test_field_v2_migration_retains_coverage_stock_and_outbox(self):
        w=await World('Field').boot();old=w.saved();old[0]=2;old[47]=20.0;old[49]=0
        old[27]=12.0;w.store[w.s.DATA]=json.dumps(old);await w.boot()
        self.assertEqual(w.saved()[0],3);self.assertEqual(w.saved()[27],12);self.assertEqual(w.saved()[50:],old[50:])
        self.assertEqual(w.saved()[47],0);self.assertEqual(w.saved()[49],[0]*64)

    async def test_physical_switch_route_and_only_named_children_changed(self):
        cab=World('Cab');cab.link_names={2:'DF:Control:Engine',3:'DF:Light:Engine',4:'DF:Gauge:Fuel',5:'Decoration'};await cab.boot()
        machine=await World('Machine').boot()
        await cab.event('touch_start',1,detected=[lummao.DetectedDetails(Key=OWNER,LinkNumber=2)])
        msg=cab.link_messages[-1];self.assertEqual(msg[1],48300)
        await machine.event('link_message',1,msg[1],msg[2],msg[3]);self.assertEqual(machine.saved()[9],1)
        initial=dict(cab.prim_params)
        visual=await machine.s.visual();await cab.event('link_message',2,48100,visual,NULL);self.assertEqual(cab.prim_params,initial)
        await cab.event('link_message',1,48100,visual,NULL);self.assertEqual(set(cab.prim_params),{3,4})

    async def test_stale_cab_shows_fault_and_extinguishes_engine_light(self):
        cab=World('Cab');cab.link_names={2:'DF:Light:Engine',3:'DF:Light:Fault'};await cab.boot()
        msg=json.dumps(dict(kind='MACHINE',engine=1,fault=0))
        await cab.event('link_message',1,48100,msg,NULL)
        self.assertEqual(cab.prim_params[2][2],lummao.Vector((0.2,0.9,0.2)))
        await cab.step(31);self.assertEqual(cab.prim_params[2][2],lummao.Vector((0.12,0.12,0.12)))
        self.assertEqual(cab.prim_params[3][2],lummao.Vector((1.0,0.1,0.1)))

    async def test_corrupted_coverage_count_locks_without_overwrite(self):
        w=await World('Field').boot();bad=w.saved();bad[43]=[str(key()),str(key()),'Plow',0,0,0,0,63]
        raw=json.dumps(bad);w.store[w.s.DATA]=raw;await w.boot()
        self.assertTrue(w.s.fault);self.assertEqual(w.store[w.s.DATA],raw)

    async def test_cab_rejects_strangers_and_noncontrol_commands(self):
        w=await World('Machine').boot()
        for actor,cmd in [(str(OTHER),'Engine'),(str(OWNER),'Sandbox diesel')]:
            await w.event('link_message',1,48300,json.dumps(dict(v=1,actor=actor,cmd=cmd)),OWNER)
        self.assertEqual(w.saved()[9],0)
        await w.event('touch_start',1,detected=[lummao.DetectedDetails(Key=OWNER,LinkNumber=3)])
        self.assertFalse(w.dialogs)

    async def test_driver_applies_work_speed_cap_and_rejects_invalid_cap(self):
        w=World('TractorDriver');w.sitter=OWNER;await w.boot();await w.event('run_time_permissions',4);await w.event('control',OWNER,1,1)
        for cap,run in [(2.0,True),(8.0,False)]:
            await w.step(1);req=w.link_messages[-1][3]
            await w.event('link_message',1,48201,json.dumps(dict(v=1,run=1,until=w.now+2,speed=cap)),req)
            self.assertEqual(w.physics,run)
            if run:self.assertEqual(w.motors[18],lummao.Vector((2.,0.,0.)))

    async def test_filter_service_requires_parts_and_never_resets_hours(self):
        w=await World('Machine').boot();await w.edit(**{'32':95.0,'31':10.0,'17':0.0})
        await w.action('Engine');await w.event('link_message',1,48200,json.dumps(dict(v=1,actor=str(OWNER),load=1000)),key())
        reply=json.loads([m for m in w.link_messages if m[1]==48201][-1][2]);self.assertEqual(reply['run'],0)
        await w.action('Engine');await w.action('Service');self.assertEqual(w.saved()[32],95)
        await w.edit(**{'17':1.0});await w.action('Service');self.assertEqual(w.saved()[32],0);self.assertEqual(w.saved()[31],10)
