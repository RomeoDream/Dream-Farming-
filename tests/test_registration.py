import unittest
from urllib.parse import urlparse,parse_qs
from world import World,OTHER

class RegistrationTests(unittest.IsolatedAsyncioTestCase):
    async def test_new_root_registration_uses_real_owner_and_object_uuids(self):
        w=await World('Register').boot();await w.action('Register')
        q=parse_qs(urlparse(w.urls[-1][2]).query)
        self.assertEqual(q,{'owner':[str(w.owner)],'farm':[str(w.key)],'object':[str(w.key)]})
        self.assertEqual(w.urls[-1][0],w.owner)
    async def test_join_farm_persists_across_script_reset(self):
        a=await World('Register').boot();b=await World('Register').boot()
        await b.action('Join farm');await b.choose(str(a.key));await b.boot();await b.action('Register')
        q=parse_qs(urlparse(b.urls[-1][2]).query);self.assertEqual(q['farm'],[str(a.key)]);self.assertEqual(q['object'],[str(b.key)])
    async def test_stranger_and_null_uuid_cannot_change_registration(self):
        w=await World('Register').boot();before=dict(w.store);await w.touch(OTHER);self.assertEqual(w.dialogs,[])
        await w.action('Join farm');await w.choose('00000000-0000-0000-0000-000000000000');self.assertEqual(w.store,before)
    async def test_owner_change_preserves_old_binding_and_blocks_registration(self):
        w=await World('Register').boot();before=dict(w.store);w.owner=OTHER;await w.boot();await w.touch()
        self.assertEqual(w.store,before);self.assertEqual(w.urls,[])
    async def test_storage_failure_does_not_offer_registration(self):
        w=World('Register');w.fail_writes=True;await w.boot();await w.touch();self.assertEqual(w.urls,[]);self.assertEqual(w.dialogs,[])

    async def test_companion_uses_controller_settings_without_competing_touch_dialog(self):
        helper=await World('Register').boot();herd=await World('Herd').boot()
        await helper.event('link_message',1,48100,'{}',helper.owner)
        await helper.touch();self.assertEqual(helper.dialogs,[])
        await herd.event('link_message',1,48131,'REGISTER_READY',herd.owner)
        await herd.submenu('Settings','SL register')
        request=[m for m in herd.link_messages if m[1]==48130 and m[2]=='REGISTER'][-1]
        await helper.event('link_message',1,request[1],request[2],helper.owner)
        self.assertIn('Register',helper.dialogs[-1][2])
