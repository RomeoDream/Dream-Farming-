// Current Garden 0.4 manure bridge. Put with DreamGarden_FarmManure.lsl
// in SAME ROOT, configured ANIMALS=0. Do not put a second farm controller here.
// Farm kg -> Garden RP units is explicitly 1:1; not a real fertilizer analysis.
string DATA="dreamfarm:gardenlink:v1";string KIND="GARDEN MANURE LINK";
integer SCHEMA=1;integer OUT=13;integer BASE=18;integer linkLast;
integer AUTO_LOAD=TRUE; // Hide bridge UI and automatically forward complete 10-unit loads.
// 8 stock;9 pending amount;10 producer sequence;11 transaction UUID;12 confirmed units.
fresh(){S=header()+[0.0,0,0,"",0]+outbox();}
list migrate(list v){return v;}
integer validSpecific(list v)
{
    if(!numeric(v,8,0.0,1000000.0) || !whole(v,9,0,100) || !whole(v,10,0,1000000000) || !whole(v,12,0,1000000))return FALSE;
    if(llList2Integer(v,9)>0 && (!uuid(llList2String(v,11)) || llList2Integer(v,10)<1))return FALSE;
    return llGetListEntryType(v,11)==TYPE_STRING;
}
tick(float dt){}
string summary(){return "Farm manure "+(string)fv(8)+" kg\nGarden reservation "+(string)iv(9)+" | Confirmed "+(string)iv(12)+"\nRequires Garden FarmManure ANIMALS=0 in this root.\nGarden collection-point menu handles onward transfer.";}
list buttons(string p)
{if(p=="settings")return ["Pause","Resume","Back","Close"];return ["Load Garden 10","Settings","Close"];}
string action(string cmd)
{
    if(cmd=="Load Garden 10")
    {
        if(iv(9)>0)return "Existing Garden delivery still pending.";
        if(fv(8)<10.0 || iv(10)>=1000000000 || iv(12)>999990)return "Need manure or sequence/counter maintenance.";
        put(8,[fv(8)-10.0]);put(9,[10]);put(10,[iv(10)+1]);put(11,[(string)llGenerateKey()]);return "Garden input reserved; identical linked event retries until acknowledged.";
    }
    return "";
}
integer credit(string kind,integer qty)
{if(kind!="MANURE" || fv(8)+qty>1000000.0)return FALSE;put(8,[fv(8)+qty]);return TRUE;}
service()
{
    if(!fault && AUTO_LOAD && !iv(4) && iv(9)==0 && fv(8)>=10.0 && iv(10)<1000000000 && iv(12)<=999990)
    {list before=S;action("Load Garden 10");if(!save(before))return;}
    if(fault || iv(9)==0 || llGetUnixTime()-linkLast<10)return;
    linkLast=llGetUnixTime();llMessageLinked(LINK_THIS,47130,llList2Json(JSON_OBJECT,["v",1,"op","MANURE","seq",iv(10),"amount",iv(9)]),(key)sv(11));
}
extraLink(integer sender,integer number,string text,key id)
{
    if(fault || sender!=llGetLinkNumber() || number!=47131 || iv(9)==0 || id!=(key)sv(11))return;
    if(llJsonValueType(text,[])!=JSON_OBJECT || llJsonGetValue(text,["v"])!="1" || llJsonGetValue(text,["op"])!="ACK" || llJsonGetValue(text,["seq"])!=(string)iv(10))return;
    list before=S;put(12,[iv(12)+iv(9)]);put(9,[0]);if(save(before))llOwnerSay("Garden collection point confirmed the manure. Use its transfer menu to send to the Garden compost bin.");
}
string visual(){return llList2Json(JSON_OBJECT,["kind",KIND,"stock",fv(8),"pending",iv(9),"fault",fault]);}
extraBoot(){if(AUTO_LOAD){UI_TOUCH=FALSE;UI_HOVER=FALSE;}}
integer extraListen(integer c,key who,string msg){return FALSE;}
integer textPage(string p){return FALSE;}
string textPrompt(){return "";}
// @include common.lslinc
