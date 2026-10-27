"""Run the real LSL scripts; mock only simulator built-ins and transport."""
import json
from pathlib import Path
import uuid
import lummao

ROOT = Path(__file__).resolve().parents[1]
OWNER = lummao.Key('11111111-1111-4111-8111-111111111111')
OTHER = lummao.Key('22222222-2222-4222-8222-222222222222')
NULL = lummao.Key('00000000-0000-0000-0000-000000000000')
ZERO = lummao.Vector((0., 0., 0.))

class Network:
    def __init__(self):
        self.worlds = {}
        self.pending = []
        self.packets = []
        self.drop = lambda *args: False

    def send(self, source, target, channel, text):
        packet = (source, target, channel, text)
        self.packets.append(packet)
        if target in self.worlds and not self.drop(*packet):
            assert len(text.encode()) <= 1024
            self.pending.append(packet)

    async def drain(self):
        count = 0
        while self.pending:
            source, target, channel, text = self.pending.pop(0)
            await self.worlds[target].event('listen', channel, 'Object', source, text)
            count += 1
            assert count < 200, 'Unexpected message loop'

class World:
    def __init__(self, module='Field', network=None, **config):
        self.module = module
        self.config = config
        self.key = lummao.Key(str(uuid.uuid4()))
        self.owner = OWNER
        self.now = 1793000000
        self.store = {}
        self.fail_writes = False
        self.dialogs = []
        self.chat = []
        self.link_messages = []
        self.alpha = {}
        self.position = ZERO
        self.velocity = ZERO
        self.rotation = lummao.Quaternion((0.,0.,0.,1.))
        self.positions = {OWNER: lummao.Vector((1., 0., 0.)), OTHER: lummao.Vector((2., 0., 0.))}
        self.net = network or Network()
        self.net.worlds[self.key] = self
        self.listen_count = 0
        self.listeners = {}
        self.timer = 0
        self.group = NULL
        self.members = set()
        self.s = None
        self.sitter = NULL
        self.physics = False
        self.motors = {}
        self.permission_requests = []
        self.link_names = {2:'DF:Stage:0',3:'DF:Stage:1',4:'DF:Stage:2',5:'DF:Stage:3',6:'DF:Stage:4',7:'DF:Stage:5',8:'Fence',9:'DF:Stage:invalid'}
        self.prim_params = {}

    def write(self, key, value):
        if self.fail_writes: return 1
        if self.store.get(key) == value: return 5
        self.store[key] = value
        return 0

    def listen(self, channel, name, who, text):
        self.listen_count += 1
        self.listeners[self.listen_count] = (channel, who)
        return self.listen_count

    def details(self, who, request):
        if request == [3]:
            if who in self.net.worlds: return [self.net.worlds[who].position]
            if who in self.positions: return [self.positions[who]]
            return []
        if request == [6,3]:
            w=self.net.worlds.get(who)
            return [w.owner,w.position] if w else []
        if request == [7]: return [self.group]
        if request == [3,5]:
            w=self.net.worlds.get(who)
            return [w.position,w.velocity] if w else []
        if request == [3,4]:
            w=self.net.worlds.get(who)
            return [w.position,w.rotation] if w else []
        raise AssertionError(request)

    def object_owner(self, who):
        if who in self.net.worlds: return self.net.worlds[who].owner
        return who

    def dialog(self, who, text, buttons, channel):
        assert len(buttons) <= 12
        assert len(text.encode()) < 512
        assert all(0 < len(b.encode()) <= 24 for b in buttons)
        self.dialogs.append((who, text, list(buttons), channel))

    async def boot(self):
        path = ROOT / 'lsl' / ('DreamFarm_' + self.module + '.lsl')
        if self.module == 'EquineStable': path = ROOT / 'experimental/DreamFarm_EquineStable.lsl'
        if self.module == 'GardenReference': path = ROOT / 'tests/fixtures/DreamGarden_Botany.reference.lsl'
        if self.module == 'GardenManure': path = ROOT / 'tests/fixtures/DreamGarden_FarmManure.v04.lsl'
        if self.module == 'BankReference': path = ROOT / 'tests/fixtures/Dream_Bill_Terminal.reference.lsl'
        self.s = lummao.compile_script_file(str(path))
        for k, v in self.config.items(): setattr(self.s, k, v)
        mocks = {
            'llGetOwner': lambda: self.owner,
            'llGetOwnerKey': self.object_owner,
            'llGetKey': lambda: self.key,
            'llGetUnixTime': lambda: self.now,
            'llGetFreeMemory': lambda: 32768,
            'llGetPos': lambda: self.position,
            'llGetRot': lambda: self.rotation,
            'llGetVel': lambda: self.velocity,
            'llLinksetDataRead': lambda key: self.store.get(key, ''),
            'llLinksetDataWrite': self.write,
            'llSetTimerEvent': lambda value: setattr(self, 'timer', value),
            'llSetText': lambda *args: None,
            'llMessageLinked': lambda *args: self.link_messages.append(args),
            'llOwnerSay': lambda text: self.chat.append(text),
            'llRegionSayTo': lambda target, ch, text: self.net.send(self.key, target, ch, text),
            'llRegionSay': lambda *args: None,
            'llGetAgentSize': lambda who: lummao.Vector((0.5, 0.5, 1.8)) if who in self.positions else ZERO,
            'llGetObjectDetails': self.details,
            'llSameGroup': lambda who: int(who in self.members),
            'llListen': self.listen,
            'llListenRemove': lambda handle: self.listeners.pop(handle, None),
            'llFrand': lambda n: float(n) * ((self.listen_count % 81 + 10) / 100.0),
            'llGenerateKey': lambda: lummao.Key(str(uuid.uuid4())),
            'llDialog': self.dialog,
            'llTextBox': lambda who, text, ch: self.dialog(who, text, [], ch),
            'llGetLinkNumber': lambda: 1,
            'llGetNumberOfPrims': lambda: 9,
            'llGetLinkName': lambda n: self.link_names.get(n,'Root'),
            'llSetLinkPrimitiveParamsFast': lambda link,params: self.prim_params.update({link:params}),
            'llSetLinkAlpha': lambda link, alpha, side: self.alpha.update({link:alpha}),
            'llSetVehicleType': lambda kind: None,
            'llSetVehicleVectorParam': lambda key,value: self.motors.update({key:value}),
            'llSetVehicleFloatParam': lambda *args: None,
            'llSetStatus': lambda key,value: setattr(self,'physics',bool(value)),
            'llSitTarget': lambda *args: None,
            'llAvatarOnSitTarget': lambda: self.sitter,
            'llReleaseControls': lambda: None,
            'llRequestPermissions': lambda who,perm: self.permission_requests.append((who,perm)),
            'llGetPermissionsKey': lambda: self.sitter,
            'llTakeControls': lambda *args: None,
            'llUnSit': lambda who: setattr(self,'sitter',NULL),
            'llSetPayPrice': lambda *args: None,
        }
        if self.module == 'BankReference':
            # Lummao omits this builtin. The unmodified adapter only sets one
            # string member; deliberately reject any unimplemented JSON path.
            def set_status(raw,path,value):
                assert path == ['status'] and isinstance(value,str)
                data=json.loads(raw);data['status']=value
                return json.dumps(data,separators=(',',':'))
            mocks['llJsonSetValue']=set_status
        for name, function in mocks.items():
            self.s.builtin_funcs[name] = function
        await self.s.execute()
        return self

    async def event(self, name, *args, detected=None):
        self.s.queue_event(name, args, detected_stack=detected)
        await self.s.execute()

    async def touch(self, who=OWNER):
        await self.event('touch_start', 1, detected=[lummao.DetectedDetails(Key=who)])

    async def choose(self, text, who=None, channel=None):
        await self.event('listen', self.dialogs[-1][3] if channel is None else channel,
                         'Resident', who or self.owner, text)

    async def action(self, text):
        await self.touch()
        await self.choose(text)

    async def submenu(self, menu, text):
        await self.action(menu)
        await self.choose(text)

    async def target(self, other):
        await self.submenu('Settings', 'Destination')
        await self.choose(str(other.key))

    async def step(self, seconds):
        self.now += seconds
        await self.event('timer')

    async def catchup(self):
        for _ in range(200):
            if self.s.fault: return
            step = 5 if self.s.S[5] == 60 else 150
            if self.now - self.s.S[3] < step: return
            await self.event('timer')
        raise AssertionError('Catchup never completed')

    async def edit(self, **values):
        # Test setup only; real user commands are exercised in each test.
        for k,v in values.items(): self.s.S[int(k)] = v
        await self.s.save(list(self.s.S))

    def saved(self): return json.loads(self.store[self.s.DATA])
