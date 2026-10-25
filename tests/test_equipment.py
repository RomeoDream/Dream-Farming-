import json
import uuid
import unittest
import lummao
from world import World,Network,OWNER,OTHER,NULL,ZERO
from test_expansion import bag

def key():return lummao.Key(str(uuid.uuid4()))

class FieldWorkTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.net=Network();self.field=await World('Field',self.net).boot();self.machine=await World('Machine',self.net).boot()
        self.job=key();self.machine.velocity=lummao.Vector((1.,0.,0.))

    async def stamp(self,cell,op='Plow',**changes):
        self.machine.position=lummao.Vector((-8.75+(cell%8)*2.5,-8.75+(cell//8)*2.5,0.))
        msg=dict(v=1,op='WORK',target=str(self.field.key),job=str(self.job),actor=str(OWNER),tool=op,crop=0,time=self.field.now)
        msg.update(changes)
        await self.field.event('listen',-163847026,'Machine',self.machine.key,json.dumps(msg))

    async def test_complete_coverage_once_without_charging_field_fuel(self):
        for i in range(63):await self.stamp(i)
        self.assertEqual(self.field.saved()[9],0)
        await self.field.boot();await self.stamp(63)
        self.assertEqual(self.field.saved()[9],1);self.assertEqual(self.field.saved()[48],1)
        self.assertEqual(self.field.saved()[28],50)
        for i in [63,1,42]:await self.stamp(i)
        self.assertEqual(self.field.saved()[48],1)
        self.assertEqual(self.field.saved()[43][7],64)

    async def test_no_work_when_stationary_foreign_or_stale(self):
        self.machine.velocity=ZERO;await self.stamp(0);self.assertEqual(self.field.saved()[43],'')
        self.machine.velocity=lummao.Vector((1.,0.,0.));self.machine.owner=OTHER
        await self.stamp(0);self.assertEqual(self.field.saved()[43],'')
        self.machine.owner=OWNER;await self.stamp(0,time=self.field.now-6)
        await self.stamp(0,crop='bogus');self.assertEqual(self.field.saved()[43],'')

    async def test_repeated_cell_and_competing_job_not_counted(self):
        await self.stamp(0);await self.stamp(0);await self.stamp(1,job=str(key()))
        self.assertEqual(self.field.saved()[43][7],1)

    async def test_sow_cannot_bypass_closed_season(self):
        await self.field.edit(**{'9':1,'46':1,'6':95.0})
        for i in range(64):await self.stamp(i,'Sow')
        self.assertEqual(self.field.saved()[8],0);self.assertEqual(self.field.saved()[24],12)
        self.assertEqual(self.field.saved()[43][7],63)

    async def test_v01_migration_preserves_pending_load_and_receipts(self):
        s=self.field.saved();s[0]=1;del s[43:50]
        stream=str(key());s[43:48]=[str(self.machine.key),3,10,'BROWNS',stream]
        s += [str(key()),2,10,'COMPOST']
        self.field.store[self.field.s.DATA]=json.dumps(s)
        await self.field.boot();m=self.field.saved()
        self.assertEqual(m[0],3);self.assertEqual(m[50:],s[43:]);self.assertEqual(m[8:43],s[8:43])

    async def test_migration_write_failure_preserves_old_bytes(self):
        old=self.field.saved();old[0]=1;del old[43:50]
        raw=json.dumps(old);self.field.store[self.field.s.DATA]=raw;self.field.fail_writes=True
        await self.field.boot();self.assertTrue(self.field.s.fault);self.assertEqual(self.field.store[self.field.s.DATA],raw)

class MachineTests(unittest.IsolatedAsyncioTestCase):
    async def request(self,w,req=None,load=1000,sender=1):
        req=req or key()
        await w.event('link_message',sender,48200,json.dumps(dict(v=1,actor=str(OWNER),load=load)),req)
        return req

    def reply(self,w):return json.loads([m for m in w.link_messages if m[1]==48201][-1][2])

    async def test_saved_fuel_lease_and_duplicate_request(self):
        w=await World('Machine').boot();await w.action('Engine');req=await self.request(w)
        after=w.saved()[8];self.assertLess(after,50);self.assertEqual(self.reply(w)['run'],1)
        await self.request(w,req);self.assertEqual(w.saved()[8],after)
        w.now+=3;await self.request(w,req);self.assertEqual(self.reply(w)['run'],0)
        await w.boot();self.assertEqual(w.saved()[9],0)

    async def test_empty_fuel_and_storage_failure_do_not_authorize_motion(self):
        w=await World('Machine').boot();await w.action('Engine');await w.edit(**{'8':0.0})
        await self.request(w);self.assertEqual(self.reply(w)['run'],0)
        await w.edit(**{'8':50.0});w.fail_writes=True;await self.request(w)
        self.assertEqual(self.reply(w)['run'],0);self.assertEqual(w.saved()[8],50)

    async def test_child_and_malformed_request_cannot_consume_fuel(self):
        w=await World('Machine').boot();await w.action('Engine')
        await self.request(w,sender=2);await self.request(w,load='bad');self.assertEqual(w.saved()[8],50)

    async def test_txago_waits_for_exact_status_and_stops_on_denial(self):
        engine=str(key());w=await World('Machine',USE_TXAGO=1,ENGINE_ID=engine).boot();await w.action('Engine')
        await self.request(w);self.assertEqual(self.reply(w)['run'],0)
        status=json.dumps(dict(kind='STATUS',engine_id=engine,state='RUNNING',allow_run=1))
        await w.event('link_message',2,-46443536,status,NULL);await self.request(w);self.assertEqual(self.reply(w)['run'],0)
        await w.event('link_message',1,-46443536,status,NULL);await self.request(w)
        self.assertEqual(self.reply(w)['run'],1);self.assertEqual(w.saved()[8],50)
        await w.event('link_message',1,-46443536,json.dumps(dict(kind='STOP',engine_id=engine)),NULL)
        await self.request(w);self.assertEqual(self.reply(w)['run'],0)

    async def test_actual_driver_waits_for_lease_then_stops_at_expiry(self):
        w=World('TractorDriver');w.sitter=OWNER;await w.boot()
        await w.event('run_time_permissions',4);await w.event('control',OWNER,1,1)
        self.assertFalse(w.physics);await w.step(1)
        req=w.link_messages[-1][3]
        reply=json.dumps(dict(v=1,run=1,until=w.now+2))
        await w.event('link_message',2,48201,reply,req);self.assertFalse(w.physics)
        await w.event('link_message',1,48201,reply,req);self.assertTrue(w.physics)
        self.assertEqual(w.motors[18],lummao.Vector((4.,0.,0.)))
        await w.step(2);self.assertFalse(w.physics)

    async def test_driver_unseating_releases_motion(self):
        w=World('TractorDriver');w.sitter=OWNER;await w.boot();await w.event('run_time_permissions',4)
        await w.step(1);req=w.link_messages[-1][3]
        await w.event('link_message',1,48201,json.dumps(dict(v=1,run=1,until=w.now+2)),req)
        w.sitter=NULL;await w.event('changed',32);self.assertFalse(w.physics);self.assertFalse(w.s.granted)

    async def test_machine_authorizations_drive_real_field_work(self):
        net=Network();m=await World('Machine',net).boot();f=await World('Field',net).boot()
        await m.target(f);await m.action('Lower or raise');await m.action('Engine');m.velocity=lummao.Vector((1.,0.,0.))
        for cell in range(64):
            m.position=lummao.Vector((-8.75+cell%8*2.5,-8.75+cell//8*2.5,0.))
            m.now+=1;f.now=m.now;await self.request(m);await net.drain()
        self.assertEqual(f.saved()[9],1);self.assertEqual(f.saved()[48],1)
        self.assertEqual(m.saved()[16],64);self.assertEqual(m.saved()[18],0)
        self.assertLess(m.saved()[8],50);self.assertEqual(f.saved()[28],50)

class UtilityTests(unittest.IsolatedAsyncioTestCase):
    async def test_pump_leak_conserves_water_and_pending_retry(self):
        net=Network();p=await World('Irrigation',net).boot();f=await World('Field',net).boot()
        await p.target(f);await p.action('Leak test')
        net.drop=lambda s,t,c,m:json.loads(m).get('op')=='ACK'
        await p.action('Pump');await net.drain()
        self.assertEqual(p.saved()[8],975);self.assertEqual(p.saved()[17],5);self.assertEqual(f.saved()[25],1020)
        await p.step(15);await net.drain();self.assertEqual(p.saved()[8],975);self.assertEqual(f.saved()[25],1020)
        net.drop=lambda *a:False;await p.step(15);await net.drain();self.assertEqual(p.saved()[p.s.OUT+2],0)

    async def test_pump_no_power_closed_valve_and_repair(self):
        net=Network();p=await World('Irrigation',net).boot();f=await World('Field',net).boot();await p.target(f)
        await p.edit(**{'9':0.0});await p.action('Pump');await net.drain();self.assertEqual(f.saved()[25],1000)
        await p.action('Valve');await p.edit(**{'9':25.0});await p.step(15);await net.drain();self.assertEqual(f.saved()[25],1000)
        await p.action('Pump');await p.action('Leak test');await p.action('Repair');self.assertEqual(p.saved()[13],0);self.assertEqual(p.saved()[15],4)

    async def test_dpc_contract_fresh_power_then_outage_stalls_processor(self):
        w=await World('Processor',USE_DPC=1).boot();await bag(w,WHEAT=6,SOYBEAN=2,HAY=2,ENERGY=100)
        await w.action('Run batch');await w.step(150);self.assertEqual(w.saved()[11],0)
        on=json.dumps(dict(v=2,op='APPLIANCE',on=1,powered=1,enabled=1))
        for _ in range(10):
            await w.event('link_message',1,7210,on,NULL);await w.step(15)
        progress=w.saved()[11];self.assertGreater(progress,0);self.assertEqual(await w.s.stock('ENERGY'),100)
        await w.event('link_message',1,7210,json.dumps(dict(v=2,op='APPLIANCE',on=1,powered=0,enabled=1)),NULL)
        await w.step(150);self.assertEqual(w.saved()[11],progress)
        await w.event('link_message',2,7210,on,NULL);await w.step(150);self.assertEqual(w.saved()[11],progress)
        demand=[json.loads(m[2]) for m in w.link_messages if m[1]==7212]
        self.assertIn(dict(op='DEMAND',watts=4000),demand)

    async def test_board_registers_only_owned_nodes_and_displays_staleness(self):
        net=Network();b=await World('Board',net).boot();f=await World('Field',net).boot()
        await b.action('Add node');await b.choose(str(f.key));await net.drain()
        self.assertEqual(len(b.s.readings),5);self.assertIn('FIELD',await b.s.summary())
        b.now+=61;self.assertIn('STALE',await b.s.summary())
        f.owner=OTHER;await b.action('Add node');await b.choose(str(f.key));self.assertEqual(len(b.saved()[8]),1)

    async def test_board_rejects_wrong_nonce_or_unknown_source(self):
        net=Network();b=await World('Board',net).boot();f=await World('Field',net).boot()
        await b.action('Add node');await b.choose(str(f.key))
        msg=json.dumps(dict(v=1,op='STATUS',nonce=str(key()),kind='FAKE',text='false',fault=0))
        await b.event('listen',-163847029,'Object',f.key,msg);self.assertEqual(b.s.readings,[])
