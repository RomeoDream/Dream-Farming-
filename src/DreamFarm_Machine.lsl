// Root controller. Pair with DreamFarm_TractorDriver in the SAME root.
// Optional TXAGO engine controller uses its real linked API; no server token here.
string DATA="dreamfarm:machine:v1";string KIND="MACHINE";
integer SCHEMA=1;integer OUT=19;integer BASE=24;
integer USE_TXAGO=FALSE;string ENGINE_ID="";
integer ENGINE_LINK=-46443536;integer WORK_NET=-163847026;
integer txReady;integer txSeen;integer txSent;string txDesired="OFF";
list IMPLEMENTS=["Plow","Sow","Harvest","Weed"];
// 8 local diesel;9 engine requested;10 implement;11 crop;12 coverage job UUID;
// 13 wear;14 last drive request;15 drive lease UTC;16 reported coverage;
// 17 repair parts;18 implement lowered;19..23 destination/outbox.
fresh(){S=header()+[50.0,0,0,0,"",0.0,"",0,0,5.0,0]+outbox();}
list migrate(list v){return v;}
integer validSpecific(list v)
{
    if(USE_TXAGO && !uuid(ENGINE_ID))return FALSE;
    if(!numeric(v,8,0.0,250.0) || !whole(v,9,0,1) || !whole(v,10,0,3) || !whole(v,11,0,5) || !numeric(v,13,0.0,100.0))return FALSE;
    if(llList2String(v,12)!="" && !uuid(llList2String(v,12)))return FALSE;
    if(llList2String(v,14)!="" && !uuid(llList2String(v,14)))return FALSE;
    return whole(v,15,0,2147483647) && whole(v,16,0,64) && numeric(v,17,0.0,1000.0) && whole(v,18,0,1);
}
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
    return "Engine requested "+(string)iv(9)+" | "+fuel+"\nImplement "+llList2String(IMPLEMENTS,iv(10))+" | Lowered "+(string)iv(18)+"\nWear "+(string)fv(13)+"% | Parts "+(string)fv(17)+"\nField coverage "+(string)iv(16)+" / 64\nDestination is the field root UUID.";
}
list buttons(string p)
{
    if(p=="settings")return ["Destination","Pause","Resume","Back","Close"];
    if(p=="implement")return IMPLEMENTS+["Back","Close"];
    if(p=="crop")return ["Wheat","Corn","Soybean","Potato","Sunflower","Grass","Back","Close"];
    return ["Engine","Implement","Crop","Lower or raise","New job","Service","Sandbox diesel","Settings","Close"];
}
string action(string cmd)
{
    if(cmd=="Engine"){put(9,[!iv(9)]);if(!iv(9)){put(15,[0]);stopDriver();engineCommand("OFF",0);}return "Engine request changed. Motion needs a current saved drive lease.";}
    if(cmd=="Implement"){page="implement";return "";}if(cmd=="Crop"){page="crop";return "";}
    if(page=="implement")
    {integer i=llListFindList(IMPLEMENTS,[cmd]);if(i>=0){put(10,[i]);put(12,[(string)llGenerateKey()]);put(16,[0]);put(18,[0]);page="main";return "Implement changed and raised. Reset old field coverage if unfinished.";}}
    if(page=="crop")
    {integer i=llListFindList(["Wheat","Corn","Soybean","Potato","Sunflower","Grass"],[cmd]);if(i>=0){put(11,[i]);put(12,[(string)llGenerateKey()]);put(16,[0]);put(18,[0]);page="main";return "Seed crop selected.";}}
    if(cmd=="Lower or raise"){put(18,[!iv(18)]);if(sv(12)=="")put(12,[(string)llGenerateKey()]);return "Implement position toggled.";}
    if(cmd=="New job"){put(12,[(string)llGenerateKey()]);put(16,[0]);return "New coverage job. Clear abandoned coverage at the field if necessary.";}
    if(cmd=="Service")
    {if(iv(9))return "Stop engine before servicing.";if(fv(17)<1.0)return "Deliver one parts unit.";put(17,[fv(17)-1.0]);put(13,[0.0]);return "Repair part consumed.";}
    if(cmd=="Sandbox diesel")
    {if(USE_TXAGO)return "TXAGO mode: refuel through the registered TXAGO system.";put(8,[50.0]);return "SANDBOX local diesel set to 50 L; no TXAGO purchase.";}
    return "";
}
integer credit(string kind,integer qty)
{
    if(kind=="DIESEL" && !USE_TXAGO && fv(8)+qty<=250.0){put(8,[fv(8)+qty]);return TRUE;}
    if(kind=="PARTS" && fv(17)+qty<=1000.0){put(17,[fv(17)+qty]);return TRUE;}return FALSE;
}
driveReply(key req,integer allowed)
{llMessageLinked(LINK_THIS,48201,llList2Json(JSON_OBJECT,["v",1,"run",allowed,"until",iv(15)]),req);}
extraLink(integer sender,integer number,string text,key id)
{
    if(sender!=llGetLinkNumber())return;
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
    if(fault || iv(4) || !iv(9) || fv(13)>=95.0){driveReply(id,FALSE);return;}
    if(llJsonValueType(text,[])!=JSON_OBJECT || llJsonGetValue(text,["v"])!="1" || llJsonGetValue(text,["actor"])!=(string)llGetOwner())return;
    integer load=(integer)llJsonGetValue(text,["load"]);if(llJsonValueType(text,["load"])!=JSON_NUMBER || (string)load!=llJsonGetValue(text,["load"]) || load<0 || load>1000)return;
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
    put(14,[(string)id]);put(15,[llGetUnixTime()+2]);
    if(!save(before)){stopDriver();driveReply(id,FALSE);return;}
    driveReply(id,TRUE);
    if(iv(18) && uuid(sv(OUT)) && uuid(sv(12)))
    {
        llRegionSayTo((key)sv(OUT),WORK_NET,llList2Json(JSON_OBJECT,["v",1,"op","WORK","target",sv(OUT),"job",sv(12),"actor",(string)llGetOwner(),"tool",llList2String(IMPLEMENTS,iv(10)),"crop",iv(11),"time",llGetUnixTime()]));
    }
}
extraBoot()
{
    llListen(WORK_NET,"",NULL_KEY,"");stopDriver();
    if(!fault){list before=S;put(9,[0]);put(15,[0]);save(before);}
    if(USE_TXAGO)engineCommand("OFF",0);
}
integer extraListen(integer c,key who,string msg)
{
    if(c!=WORK_NET)return FALSE;
    if(fault || who!=(key)sv(OUT) || llGetOwnerKey(who)!=llGetOwner() || llJsonValueType(msg,[])!=JSON_OBJECT || llJsonGetValue(msg,["v"])!="1" || llJsonGetValue(msg,["job"])!=sv(12) || llJsonGetValue(msg,["op"])!="WORK_STATUS")return TRUE;
    integer n=(integer)llJsonGetValue(msg,["coverage"]);if(n<iv(16) || n>64)return TRUE;
    list before=S;put(16,[n]);if(llJsonGetValue(msg,["done"])=="1")put(18,[0]);save(before);return TRUE;
}
service()
{
    if(fault || iv(4) || !iv(9)){stopDriver();engineCommand("OFF",0);}
    if(USE_TXAGO && llGetUnixTime()-txSeen>45){txReady=FALSE;stopDriver();}
}
string visual(){return llList2Json(JSON_OBJECT,["kind",KIND,"engine",iv(9),"lowered",iv(18),"coverage",iv(16),"fault",fault]);}
integer textPage(string p){return FALSE;}
string textPrompt(){return "";}
// @include common.lslinc
