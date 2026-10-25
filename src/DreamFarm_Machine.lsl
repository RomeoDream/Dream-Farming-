// Root controller. Pair with DreamFarm_TractorDriver in the SAME root.
// Optional TXAGO engine controller uses its real linked API; no server token here.
string DATA="dreamfarm:machine:v1";string KIND="MACHINE";
integer SCHEMA=2;integer OUT=34;integer BASE=39;
integer USE_TXAGO=FALSE;string ENGINE_ID="";
integer ENGINE_LINK=-46443536;integer WORK_NET=-163847026;
integer txReady;integer txSeen;integer txSent;string txDesired="OFF";
list IMPLEMENTS=["Plow","Sow","Harvest","Weed","Spread"];
list SPREAD_MATERIALS=["MANURE","SLURRY","COMPOST","DIGESTATE"];
// @include plot_geometry.lslinc
// 8 local diesel;9 engine requested;10 implement;11 crop;12 coverage job UUID;
// 13 wear;14 last drive request;15 drive lease UTC;16 reported coverage;
// 17 parts;18 lowered;19 PTO;20 hydraulic circuit;21 hitch latched;
// 22 spread material;23 dose;24..27 material stock;28..29 spread coverage masks;
// 30 reserved cell(-1 none);31 engine hours;32 filter wear;33 hydraulic fluid;
// 34..38 destination/outbox. Hitch is a control interlock, not physical linking.
list equipmentDefaults(){return [0,1,1,0,1,0.0,0.0,0.0,0.0,0,0,-1,0.0,0.0,100.0];}
fresh(){S=header()+[50.0,0,0,0,"",0.0,"",0,0,5.0,0]+equipmentDefaults()+outbox();}
list migrate(list v)
{
    if(whole(v,0,1,1) && llGetListLength(v)>=24 && (llGetListLength(v)-24)%4==0)
    {v=llList2List(v,0,18)+equipmentDefaults()+llList2List(v,19,-1);v=llListReplaceList(v,[2],0,0);}
    return v;
}
integer validSpecific(list v)
{
    if(USE_TXAGO && !uuid(ENGINE_ID))return FALSE;
    if(FIELD_WIDTH<=0.0 || FIELD_DEPTH<=0.0 || !numeric(v,8,0.0,250.0) || !whole(v,9,0,1) || !whole(v,10,0,4) || !whole(v,11,0,5) || !numeric(v,13,0.0,100.0))return FALSE;
    if(llList2String(v,12)!="" && !uuid(llList2String(v,12)))return FALSE;
    if(llList2String(v,14)!="" && !uuid(llList2String(v,14)))return FALSE;
    integer i;for(i=19;i<=21;++i)if(!whole(v,i,0,1))return FALSE;
    for(i=24;i<=27;++i)if(!numeric(v,i,0.0,500.0))return FALSE;
    float held=0.0;for(i=24;i<=27;++i)held+=llList2Float(v,i);
    if(held+llList2Integer(v,OUT+2)>500.01)return FALSE;
    if(!whole(v,22,0,3) || llListFindList([1,2,4],[llList2Integer(v,23)])<0 || !whole(v,30,-1,63))return FALSE;
    for(i=28;i<=29;++i)if(!whole(v,i,-2147483647-1,2147483647))return FALSE;
    if(llList2Integer(v,10)==4 && llList2Integer(v,16)!=countCells(llList2Integer(v,28),llList2Integer(v,29)))return FALSE;
    if(llList2Integer(v,OUT+2)>0)
    {
        string k="SPREAD|"+llList2String(SPREAD_MATERIALS,llList2Integer(v,22))+"|"+(string)llList2Integer(v,30);
        if(llList2Integer(v,10)!=4 || llList2Integer(v,30)<0 || llList2String(v,OUT+3)!=k || llList2Integer(v,OUT+2)!=llList2Integer(v,23))return FALSE;
        if(cellMarked(llList2Integer(v,28),llList2Integer(v,29),llList2Integer(v,30)))return FALSE;
    }
    else if(llList2Integer(v,30)!=-1)return FALSE;
    return whole(v,15,0,2147483647) && whole(v,16,0,64) && numeric(v,17,0.0,1000.0) && whole(v,18,0,1) && numeric(v,31,0.0,1000000.0) && numeric(v,32,0.0,100.0) && numeric(v,33,0.0,100.0);
}
float spreadStock(){return fv(24)+fv(25)+fv(26)+fv(27);}
integer implementReady()
{return iv(18) && iv(21) && iv(20) && fv(33)>0.0 && ((iv(10)!=2 && iv(10)!=4) || iv(19));}
float driveLimit(){if(iv(18))return llList2Float([2.0,2.0,2.0,3.0,2.0],iv(10));return 4.0;}
newJob()
{put(12,[(string)llGenerateKey()]);put(16,[0]);put(28,[0]);put(29,[0]);put(18,[0]);}
tick(float dt){} // Real-time drive leases consume real-time fuel, not crop clock.
engineCommand(string desired,integer load)
{
    if(!USE_TXAGO)return;
    if(desired==txDesired && llGetUnixTime()-txSent<20)return;
    txDesired=desired;txSent=llGetUnixTime();txReady=FALSE;
    llMessageLinked(LINK_THIS,ENGINE_LINK,llList2Json(JSON_OBJECT,["kind","COMMAND","engine_id",ENGINE_ID,"state",desired,"load_permille",load]),NULL_KEY);
}
stopDriver()
{llMessageLinked(LINK_THIS,48202,"STOP",NULL_KEY);}
string summary()
{
    string fuel="Local diesel "+(string)fv(8)+" L";if(USE_TXAGO)fuel="TXAGO server fuel authority";
    return "Engine "+(string)iv(9)+" | "+fuel+"\n"+llList2String(IMPLEMENTS,iv(10))+" | Lowered "+(string)iv(18)+" | PTO "+(string)iv(19)+" | Hitch "+(string)iv(21)+"\nWear "+(string)fv(13)+"% | Hours "+(string)fv(31)+" | Filter "+(string)fv(32)+"%\nCoverage "+(string)iv(16)+" / 64 | Dose "+(string)iv(23)+" | Load "+(string)spreadStock()+" | Pending "+(string)iv(OUT+2);
}
list buttons(string p)
{
    if(p=="settings")return ["Destination","Pause","Resume","Back","Close"];
    if(p=="implement")return IMPLEMENTS+["Back","Close"];
    if(p=="crop")return ["Wheat","Corn","Soybean","Potato","Sunflower","Grass","Back","Close"];
    if(p=="cab")return ["PTO","Hydraulics","Hitch","Inspect","Back","Close"];
    if(p=="spreader")return ["Manure","Slurry","Compost","Digestate","Dose 1","Dose 2","Dose 4","Back","Close"];
    return ["Engine","Implement","Crop","Lower or raise","New job","Cab controls","Spreader setup","Service","Sandbox diesel","Settings","Close"];
}
string action(string cmd)
{
    if(cmd=="Engine"){put(9,[!iv(9)]);if(!iv(9)){put(15,[0]);put(19,[0]);stopDriver();engineCommand("OFF",0);}return "Engine request changed. Motion needs a current saved drive lease.";}
    if(cmd=="Cab controls"){page="cab";return "";}if(cmd=="Spreader setup"){page="spreader";return "";}
    if(cmd=="Inspect")return "Hydraulic fluid "+(string)fv(33)+"% | Filter wear "+(string)fv(32)+"% | Parts "+(string)fv(17)+" | PTO "+(string)iv(19)+" | Hydraulic circuit "+(string)iv(20);
    if(cmd=="PTO")
    {if(!iv(19) && (!iv(9) || !iv(21)))return "Start engine and latch hitch before engaging PTO.";put(19,[!iv(19)]);return "PTO toggled.";}
    if(cmd=="Hydraulics"){put(20,[!iv(20)]);return "Hydraulic circuit toggled.";}
    if(cmd=="Hitch")
    {if(iv(9) || iv(18) || iv(19) || iv(OUT+2)>0)return "Stop engine, raise implement and finish delivery before changing hitch latch.";put(21,[!iv(21)]);return "Hitch interlock changed; this does not link or tow another object.";}
    if(iv(OUT+2)>0 && (page=="implement" || page=="crop" || page=="spreader" || cmd=="New job"))return "Finish the saved spread dose before changing this job.";
    if(cmd=="Implement"){page="implement";return "";}if(cmd=="Crop"){page="crop";return "";}
    if(page=="implement")
    {integer i=llListFindList(IMPLEMENTS,[cmd]);if(i>=0){put(10,[i]);newJob();page="main";return "Implement changed and raised. Reset old field coverage if unfinished.";}}
    if(page=="crop")
    {integer i=llListFindList(["Wheat","Corn","Soybean","Potato","Sunflower","Grass"],[cmd]);if(i>=0){put(11,[i]);newJob();page="main";return "Seed crop selected.";}}
    if(page=="spreader")
    {
        integer i=llListFindList(["Manure","Slurry","Compost","Digestate"],[cmd]);
        if(i>=0){put(22,[i]);newJob();return "Spreader material selected; new job raised.";}
        i=llListFindList(["Dose 1","Dose 2","Dose 4"],[cmd]);if(i>=0){put(23,[llList2Integer([1,2,4],i)]);newJob();return "Dose selected; new job raised. Repeated passes can overapply.";}
    }
    if(cmd=="Lower or raise")
    {if(!iv(20) || !iv(21) || fv(33)<0.1)return "Need latched hitch, open hydraulic circuit and hydraulic fluid.";put(33,[clamp(fv(33)-0.1,0.0,100.0)]);put(18,[!iv(18)]);if(sv(12)=="")put(12,[(string)llGenerateKey()]);return "Implement position toggled.";}
    if(cmd=="New job"){newJob();return "New coverage job, implement raised. Clear abandoned field coverage if necessary.";}
    if(cmd=="Service")
    {if(iv(9))return "Stop engine before servicing.";if(fv(17)<1.0)return "Deliver one parts unit.";put(17,[fv(17)-1.0]);put(13,[0.0]);put(32,[0.0]);put(33,[100.0]);return "Service kit consumed; machinery, filter and hydraulic fluid serviced.";}
    if(cmd=="Sandbox diesel")
    {if(USE_TXAGO)return "TXAGO mode: refuel through the registered TXAGO system.";put(8,[50.0]);return "SANDBOX local diesel set to 50 L; no TXAGO purchase.";}
    return "";
}
integer credit(string kind,integer qty)
{
    if(kind=="DIESEL" && !USE_TXAGO && fv(8)+qty<=250.0){put(8,[fv(8)+qty]);return TRUE;}
    if(kind=="PARTS" && fv(17)+qty<=1000.0){put(17,[fv(17)+qty]);return TRUE;}
    integer i=llListFindList(SPREAD_MATERIALS,[kind]);
    if(i>=0 && spreadStock()+iv(OUT+2)+qty<=500.0){put(24+i,[fv(24+i)+qty]);return TRUE;}return FALSE;
}
prepareSpread()
{
    if(iv(OUT+2)>0 || iv(30)>=0 || !implementReady() || iv(10)!=4 || !uuid(sv(OUT)) || !uuid(sv(12)))return;
    float speed=llVecMag(llGetVel());if(speed<0.2 || speed>2.5)return;
    if(!near(llGetOwner(),40.0))return;
    list d=llGetObjectDetails((key)sv(OUT),[OBJECT_POS,OBJECT_ROT]);if(llGetListLength(d)!=2)return;
    integer cell=plotCell(llGetPos(),llList2Vector(d,0),llList2Rot(d,1));
    if(cell<0 || cellMarked(iv(28),iv(29),cell))return;
    integer slot=24+iv(22);integer dose=iv(23);if(fv(slot)<dose)return;
    string kind="SPREAD|"+llList2String(SPREAD_MATERIALS,iv(22))+"|"+(string)cell;
    if(!startTransfer(kind,dose))return;
    put(slot,[fv(slot)-dose]);put(30,[cell]);txLast=0;
}
driveReply(key req,integer allowed)
{llMessageLinked(LINK_THIS,48201,llList2Json(JSON_OBJECT,["v",1,"run",allowed,"until",iv(15),"speed",driveLimit()]),req);}
extraLink(integer sender,integer number,string text,key id)
{
    if(sender!=llGetLinkNumber())return;
    if(number==48300)
    {
        if(fault || iv(4) || !ownerNear() || llJsonValueType(text,[])!=JSON_OBJECT || llJsonGetValue(text,["v"])!="1" || llJsonGetValue(text,["actor"])!=(string)llGetOwner())return;
        string cmd=llJsonGetValue(text,["cmd"]);
        if(llListFindList(["Engine","PTO","Hydraulics","Hitch","Lower or raise"],[cmd])<0 || !advance())return;
        list before=S;string old=page;page="main";string result=action(cmd);page=old;
        if(save(before)){llOwnerSay(result);service();render();}return;
    }
    if(USE_TXAGO && number==ENGINE_LINK && llJsonValueType(text,[])==JSON_OBJECT && llJsonGetValue(text,["engine_id"])==ENGINE_ID)
    {
        string k=llJsonGetValue(text,["kind"]);
        if(k=="STOP"){txReady=FALSE;stopDriver();}
        if(k=="STATUS")
        {
            txSeen=llGetUnixTime();txReady=llJsonGetValue(text,["allow_run"])=="1" && llJsonGetValue(text,["state"])==txDesired && txDesired!="OFF";
            if(!txReady)stopDriver();
        }
        return;
    }
    if(number!=48200 || !uuid((string)id))return;
    if(fault || iv(4) || !iv(9) || fv(13)>=95.0 || fv(32)>=95.0 || fv(31)>=1000000.0){driveReply(id,FALSE);return;}
    if(llJsonValueType(text,[])!=JSON_OBJECT || llJsonGetValue(text,["v"])!="1" || llJsonGetValue(text,["actor"])!=(string)llGetOwner())return;
    integer load=(integer)llJsonGetValue(text,["load"]);if(llJsonValueType(text,["load"])!=JSON_NUMBER || (string)load!=llJsonGetValue(text,["load"]) || load<0 || load>1000)return;
    if(implementReady() && iv(19) && load<300)load=300;
    string desired="IDLE";if(load>0)desired="RUNNING";
    if(USE_TXAGO)
    {
        engineCommand(desired,load);
        if(!txReady || llGetUnixTime()-txSeen>45){driveReply(id,FALSE);return;}
    }
    if(sv(14)==(string)id){driveReply(id,llGetUnixTime()<iv(15));return;}
    float fuel=0.0003+0.003*(float)load/1000.0;
    if(!USE_TXAGO && fv(8)<fuel){stopDriver();driveReply(id,FALSE);return;}
    list before=S;
    if(!USE_TXAGO)put(8,[fv(8)-fuel]);put(13,[clamp(fv(13)+0.0005,0.0,100.0)]);
    put(31,[clamp(fv(31)+1.0/3600.0,0.0,1000000.0)]);put(32,[clamp(fv(32)+0.0003,0.0,100.0)]);
    put(14,[(string)id]);put(15,[llGetUnixTime()+2]);
    prepareSpread();
    if(!save(before)){stopDriver();driveReply(id,FALSE);return;}
    driveReply(id,TRUE);
    sendTransfer();
    if(implementReady() && iv(10)!=4 && uuid(sv(OUT)) && uuid(sv(12)))
    {
        llRegionSayTo((key)sv(OUT),WORK_NET,llList2Json(JSON_OBJECT,["v",1,"op","WORK","target",sv(OUT),"job",sv(12),"actor",(string)llGetOwner(),"tool",llList2String(IMPLEMENTS,iv(10)),"crop",iv(11),"time",llGetUnixTime()]));
    }
    llMessageLinked(LINK_SET,VIEW,visual(),NULL_KEY);
}
extraBoot()
{
    SPREAD_LINKS=TRUE;UI_ROOT_ONLY=TRUE;llListen(WORK_NET,"",NULL_KEY,"");stopDriver();
    if(!fault){list before=S;put(9,[0]);put(15,[0]);put(19,[0]);save(before);}
    if(USE_TXAGO)engineCommand("OFF",0);
}
integer extraListen(integer c,key who,string msg)
{
    if(c!=WORK_NET)return FALSE;
    if(fault || iv(10)==4 || who!=(key)sv(OUT) || llGetOwnerKey(who)!=llGetOwner() || llJsonValueType(msg,[])!=JSON_OBJECT || llJsonGetValue(msg,["v"])!="1" || llJsonGetValue(msg,["job"])!=sv(12) || llJsonGetValue(msg,["op"])!="WORK_STATUS")return TRUE;
    integer n=(integer)llJsonGetValue(msg,["coverage"]);
    if(llJsonValueType(msg,["coverage"])!=JSON_NUMBER || llJsonGetValue(msg,["coverage"])!=(string)n || n<iv(16) || n>64 || llJsonGetValue(msg,["done"])!=(string)(n==64))return TRUE;
    list before=S;put(16,[n]);if(llJsonGetValue(msg,["done"])=="1")put(18,[0]);save(before);return TRUE;
}
service()
{
    sendTransfer();
    if(fault || iv(4) || !iv(9)){stopDriver();engineCommand("OFF",0);}
    if(USE_TXAGO && llGetUnixTime()-txSeen>45){txReady=FALSE;stopDriver();}
}
string visual(){return llList2Json(JSON_OBJECT,["kind",KIND,"engine",iv(9),"lowered",iv(18),"coverage",iv(16),"pto",iv(19),"hitch",iv(21),"hydraulics",iv(20),"fuel",fv(8),"external_fuel",USE_TXAGO,"wear",fv(13),"hours",fv(31),"pending",iv(OUT+2),"fault",fault]);}
integer textPage(string p){return FALSE;}
string textPrompt(){return "";}
transferAck(string kind,integer qty)
{
    integer cell=iv(30);if(cell<0 || cell>63)return;
    integer slot=28;integer bit=cell;if(cell>=32){slot=29;bit-=32;}
    put(slot,[iv(slot)|(1<<bit)]);put(30,[-1]);put(16,[countCells(iv(28),iv(29))]);
    if(iv(16)==64)put(18,[0]);
}
// @include common.lslinc
