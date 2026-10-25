// Receives mature COMPOST from DreamFarm_Compost, then uses the existing
// Dream-Garden Botany MANURE protocol. Basic DreamGarden_Plot is not compatible.
string DATA="dreamfarm:applicator:v1";
string KIND="GARDEN APPLICATOR";
integer OUT=15;
integer BASE=20;
integer GARDEN=-163847020;
integer gardenLast;
integer selectingGarden;
// 8 mature compost kg;9 Garden target UUID;10 reserved dose kg;
// 11 request UUID;12 original UTC timestamp;13 last outcome;14 applications;
// 15..19 unused transfer outbox (for common schema); receipts follow.
fresh(){S=header()+[0.0,"",0,"",0,"Ready",0]+outbox();}
integer validSpecific(list v)
{
    if(!numeric(v,8,0.0,1000000.0) || !whole(v,10,0,2) || !whole(v,12,0,2147483647) || !whole(v,14,0,1000000))return FALSE;
    if(llList2Integer(v,10)!=0 && llList2Integer(v,10)!=2)return FALSE;
    string target=llList2String(v,9);if(target!="" && !uuid(target))return FALSE;
    if(llGetListEntryType(v,13)!=TYPE_STRING || llStringLength(llList2String(v,13))>200)return FALSE;
    if(llList2Integer(v,10)>0 && (!uuid(llList2String(v,11)) || !uuid(target) || llList2Integer(v,12)==0))return FALSE;
    return TRUE;
}
tick(float dt){}
string summary()
{return "Mature compost "+(string)((integer)fv(8))+" kg\nReserved dose "+(string)iv(10)+" kg | Confirmed "+(string)iv(14)+"\n"+sv(13)+"\nDestination setting: Garden Botany root UUID.\nUnconfirmed doses remain reserved; never automatically refunded.";}
list buttons(string p)
{
    if(p=="settings")return ["Destination","Pause","Resume","Back","Close"];
    if(p=="discard")return ["Confirm discard","Back","Close"];
    return ["Apply compost","Resolve timeout","Settings","Close"];
}
string action(string cmd)
{
    if(cmd=="Apply compost")
    {
        if(iv(10)>0)return "Prior dose is unresolved. Inspect the plant before resolving.";
        if(fv(8)<2.0)return "Need 2 kg mature compost delivered from the farm.";
        if(!uuid(sv(OUT)) || !near((key)sv(OUT),8.0) || llGetOwnerKey((key)sv(OUT))!=llGetOwner())return "Set a same-owner Botany plant destination within 8 m.";
        if(iv(14)>=1000000)return "Application history limit reached.";
        put(9,[sv(OUT)]);put(8,[fv(8)-2.0]);put(10,[2]);put(11,[(string)llGenerateKey()]);put(12,[llGetUnixTime()]);put(13,["Dose reserved; awaiting Garden confirmation."]);
        return "Applying mature compost through Garden's aged-manure action.";
    }
    if(cmd=="Resolve timeout")
    {
        if(iv(10)==0)return "No unresolved dose.";
        if(llGetUnixTime()-iv(12)<=10)return "Wait until the Garden request has expired.";
        page="discard";return "Inspect the Garden plant. Confirm discard releases the hold WITHOUT restoring the dose, preventing duplicate spending.";
    }
    if(cmd=="Confirm discard")
    {
        if(iv(10)==0 || llGetUnixTime()-iv(12)<=10)return "No expired dose to resolve.";
        put(10,[0]);put(13,["Uncertain dose discarded by owner; not refunded."]);page="main";return sv(13);
    }
    return "";
}
integer credit(string kind,integer qty)
{if(kind!="COMPOST" || fv(8)+(float)qty>1000000.0)return FALSE;put(8,[fv(8)+(float)qty]);return TRUE;}
string visual(){return llList2Json(JSON_OBJECT,["kind",KIND,"stock",fv(8),"pending",iv(10),"fault",fault]);}
extraBoot(){llListen(GARDEN,"",NULL_KEY,"");}
integer extraListen(integer c,key who,string msg)
{
    if(c!=GARDEN)return FALSE;
    if(fault || iv(10)==0 || who!=(key)sv(9) || llGetOwnerKey(who)!=llGetOwner() || llStringLength(msg)>1000)return TRUE;
    if(llJsonValueType(msg,[])!=JSON_OBJECT || llJsonGetValue(msg,["v"])!="1" || llJsonGetValue(msg,["target"])!=(string)llGetKey())return TRUE;
    if(llJsonGetValue(msg,["req"])!=sv(11) || llJsonGetValue(msg,["tool"])!="MANURE")return TRUE;
    string op=llJsonGetValue(msg,["op"]);
    if(op=="ACK")
    {
        list before=S;put(10,[0]);put(14,[iv(14)+1]);put(13,["Garden confirmed mature compost application."]);
        if(save(before))llOwnerSay(sv(13));
    }
    // Even ERR does not refund: an earlier ACK could have been lost, then
    // the target paused/reconfigured before a retry. Keep a conservative hold.
    if(op=="ERR")
    {list old=S;put(13,["Garden declined or changed state. Dose held; inspect target, then resolve timeout."]);save(old);}
    return TRUE;
}
service()
{
    if(fault || iv(10)==0 || llGetUnixTime()-iv(12)>8){llSetTimerEvent(15.0);return;}
    if(llGetUnixTime()-gardenLast<2)return;
    gardenLast=llGetUnixTime();
    llRegionSayTo((key)sv(9),GARDEN,llList2Json(JSON_OBJECT,["v",1,"op","USE","tool","MANURE",
        "actor",(string)llGetOwner(),"req",sv(11),"time",iv(12),"target",sv(9)]));
    // Common 15-second timer is replaced while a short Garden request is live.
    llSetTimerEvent(2.0);
}
// @include common.lslinc
