import json
import unittest
from world import World,Network,OWNER,OTHER,NULL
from test_expansion import bag
from test_equipment import key

class HerdTests(unittest.IsolatedAsyncioTestCase):
    async def test_individual_identity_rename_reset_and_valid_record(self):
        w=await World('Herd').boot();await w.submenu('Manage','Cow');a=await w.s.animal(0)
        await w.action('Rename');await w.choose('Daisy');await w.boot()
        self.assertEqual((await w.s.animal(0))[0],a[0]);self.assertEqual((await w.s.animal(0))[1],'Daisy')
        self.assertTrue(await w.s.validSpecific(w.s.S))
        for p in ['main','animals','manage','material','export','settings']:await w.s.show(p)

    async def test_feed_water_finite_manure_and_milk(self):
        w=await World('Herd').boot();await w.submenu('Manage','Cow');await bag(w,FEED=20,WATER=60)
        await w.step(3600);await w.catchup()
        self.assertAlmostEqual(await w.s.stock('FEED'),0,places=4);self.assertAlmostEqual(await w.s.stock('WATER'),0,places=4)
        self.assertAlmostEqual(await w.s.stock('MANURE'),13,places=3);self.assertGreater(await w.s.stock('MILK'),10)

    async def test_birth_pedigree_young_growth_and_no_newborn_milk(self):
        w=await World('Herd').boot();await w.submenu('Manage','Cow');await w.submenu('Manage','Bull');await w.action('Breed')
        mother=await w.s.animal(0);father=await w.s.animal(1);mother[10]=0.0
        await w.s.putAnimal(0,mother);await w.s.save(list(w.s.S));await bag(w,FEED=100,WATER=300)
        await w.step(150);self.assertEqual(await w.s.countAnimals(),3)
        child=await w.s.animal(2);self.assertEqual(child[11],father[0]);self.assertEqual(child[12],mother[0]);self.assertEqual(child[4],0)
        self.assertEqual(child[14],0);self.assertNotIn(child[0],[father[0],mother[0]])
        await w.boot();await w.step(150);self.assertEqual(await w.s.countAnimals(),3);self.assertGreater((await w.s.animal(2))[4],0)
        self.assertTrue(await w.s.validSpecific(w.s.S))

    async def test_breeding_blocks_related_immature_or_stressed_male(self):
        w=await World('Herd').boot();await w.submenu('Manage','Cow');await w.submenu('Manage','Bull')
        female=await w.s.animal(0);male=await w.s.animal(1);male[11]=female[0]
        await w.s.putAnimal(1,male);await w.s.save(list(w.s.S));await w.action('Breed');self.assertEqual((await w.s.animal(0))[10],-1)
        male[11]='';male[9]=80.0;await w.s.putAnimal(1,male);await w.s.save(list(w.s.S));await w.action('Breed')
        self.assertEqual((await w.s.animal(0))[10],-1)

    async def test_capacity_holds_due_litter_and_treatment_consumes_medicine(self):
        w=await World('Herd').boot()
        for name in ['Sow','Boar','Cow','Cow','Cow']:await w.submenu('Manage',name)
        await w.action('Breed');a=await w.s.animal(0);a[10]=0.0;await w.s.putAnimal(0,a);await w.s.save(list(w.s.S))
        await bag(w,FEED=100,WATER=300,MEDICINE=1);await w.step(150)
        self.assertEqual(await w.s.countAnimals(),5);self.assertEqual((await w.s.animal(0))[10],0)
        await w.action('Treat');self.assertEqual(await w.s.stock('MEDICINE'),0)

    async def test_death_stops_production_and_cannot_be_treated_back_alive(self):
        w=await World('Herd').boot();await w.submenu('Manage','Cow')
        a=await w.s.animal(0);a[6]=.001;a[7]=100.;a[8]=100.;a[9]=100.
        await w.s.putAnimal(0,a);await w.s.save(list(w.s.S));await w.step(150)
        self.assertEqual((await w.s.animal(0))[15],0)
        await bag(w,MEDICINE=1);await w.action('Treat');self.assertEqual(await w.s.stock('MEDICINE'),1)
        await w.step(150);self.assertEqual(await w.s.stock('MILK'),0);self.assertEqual(w.saved()[20],1)

    async def test_individual_herd_manure_enters_compost_chain(self):
        net=Network();h=await World('Herd',net).boot();c=await World('Compost',net).boot();await bag(h,MANURE=10)
        await h.target(c);await h.action('Export');await h.choose('Select material');await h.choose('Manure');await h.choose('Send 10');await net.drain()
        self.assertEqual(await h.s.stock('MANURE'),0);self.assertEqual(c.saved()[8],10)

class OfficeTests(unittest.IsolatedAsyncioTestCase):
    async def make_bill(self):
        business=str(key());w=await World('Office',USE_BANK=1,BUSINESS_ID=business).boot()
        await w.action('New work order');await w.choose('Plow north field');await w.action('Finish job')
        await w.action('Invoice details');await w.choose(f'{OTHER}|2500|7');await w.action('Issue invoice')
        return w,business,await w.s.job(0)

    async def status(self,w,business,j,state,paid,**changes):
        msg=dict(v=1,bill=j[4],payer=j[5],business=business,amount=str(j[6]),paid=str(paid),status=state,ok='1')
        msg.update(changes);await w.event('link_message',1,42002,json.dumps(msg),OTHER)

    async def test_bank_disabled_never_issues_or_claims_payment(self):
        w=await World('Office').boot();await w.action('New work order');await w.choose('Feed cattle');await w.action('Finish job');await w.action('Issue invoice')
        self.assertEqual((await w.s.job(0))[4],'');self.assertEqual(w.saved()[14],0)
        self.assertFalse(any(m[1]==42001 for m in w.link_messages))

    async def test_immutable_invoice_retry_reset_and_paid_once(self):
        w,b,j=await self.make_bill();request=[m for m in w.link_messages if m[1]==42001][-1]
        self.assertEqual(json.loads(request[2])['amount'],2500)
        await w.boot();retry=[m for m in w.link_messages if m[1]==42001][-1];self.assertEqual(request[2],retry[2])
        await self.status(w,b,j,'PAID',2500);await self.status(w,b,j,'PAID',2500)
        self.assertEqual(w.saved()[14],2500);self.assertEqual(w.saved()[15],1)
        await self.status(w,b,j,'OPEN',0);self.assertEqual((await w.s.job(0))[8],'PAID')
        await w.action('Issue invoice');self.assertEqual((await w.s.job(0))[4],j[4])

    async def test_partial_bad_identity_wrong_amount_and_fake_full_payment(self):
        w,b,j=await self.make_bill();await self.status(w,b,j,'PARTIAL',1000);self.assertEqual(w.saved()[14],0)
        await self.status(w,b,j,'PAID',2000);await self.status(w,b,j,'PAID',2500,amount='2600');await self.status(w,str(key()),j,'PAID',2500)
        self.assertEqual(w.saved()[14],0);self.assertEqual((await w.s.job(0))[7],1000)
        await self.status(w,b,j,'OPEN',0);self.assertEqual((await w.s.job(0))[7],1000)

    async def test_failed_paid_save_does_not_lose_invoice_or_double_total(self):
        w,b,j=await self.make_bill();w.fail_writes=True;await self.status(w,b,j,'PAID',2500)
        self.assertEqual(w.saved()[14],0);w.fail_writes=False;await w.boot();await self.status(w,b,j,'PAID',2500)
        self.assertEqual(w.saved()[14],2500)

    async def test_worker_only_updates_assigned_job_no_invoice_privilege(self):
        w=World('Office',GROUP_WORK=1);w.group=key();w.members={OTHER};await w.boot()
        await w.action('New work order');await w.choose('Feed cattle')
        await w.touch(OTHER);self.assertIn('Finish job',w.dialogs[-1][2]);self.assertNotIn('Issue invoice',w.dialogs[-1][2])
        await w.choose('Finish job',who=OTHER);self.assertEqual((await w.s.job(0))[3],0)
        await w.action('New work order');await w.choose(f'Feed sheep|{OTHER}')
        await w.touch(OTHER);await w.choose('Finish job',who=OTHER);self.assertEqual((await w.s.job(1))[3],2)

    async def test_real_bank_adapter_contract_and_forged_radio_rejection(self):
        w,b,j=await self.make_bill();bank=key()
        adapter=await World('BankReference',BANK_ROOT=bank,BUSINESS_ID=b).boot()
        request=[m for m in w.link_messages if m[1]==42001][-1]
        await adapter.event('link_message',1,42001,request[2],request[3])
        sent=json.loads(adapter.net.packets[-1][3]);self.assertEqual(sent['op'],'BILL_CREATE');self.assertEqual(sent['bill'],j[4])
        msg=json.dumps(dict(v=1,op='BILL_RESULT',bill=j[4],payer=j[5],business=b,amount='2500',paid='2500',status='PAID',ok='1'))
        await adapter.event('listen',-80425191,'Bank',OTHER,msg);self.assertFalse(adapter.link_messages)
        await adapter.event('listen',-80425191,'Bank',bank,msg)
        response=adapter.link_messages[-1];self.assertEqual(response[1],42002)
        await w.event('link_message',1,response[1],response[2],response[3]);self.assertEqual(w.saved()[14],2500)
        await adapter.boot();await adapter.event('link_message',1,42003,j[4],OTHER)
        replay=adapter.link_messages[-1];await w.event('link_message',1,replay[1],replay[2],replay[3]);self.assertEqual(w.saved()[14],2500)

class NewModuleValidation(unittest.IsolatedAsyncioTestCase):
    async def test_multibyte_work_order_keeps_dialog_below_byte_limit(self):
        w=await World('Office').boot();await w.action('New work order');await w.choose('🌾'*80)
        self.assertLess(len(w.dialogs[-1][1].encode()),512)

    async def test_all_new_modules_boot_save_and_menus(self):
        for name in ['Herd','Machine','Irrigation','Board','Office']:
            w=await World(name).boot();self.assertFalse(w.s.fault,name)
            self.assertTrue(await w.s.validBase(w.s.S),name);self.assertTrue(await w.s.validSpecific(w.s.S),name)
            for p in ['main','settings']:await w.s.show(p)
            before=w.saved();await w.boot();self.assertEqual(before,w.saved())
