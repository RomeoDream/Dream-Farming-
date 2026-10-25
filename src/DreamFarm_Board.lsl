// Read-only local farm monitor. Register up to 16 same-owner object roots.
string DATA="dreamfarm:board:v1";string KIND="FARM BOARD";
integer SCHEMA=1;integer OUT=12;integer BASE=17;
integer polled;string nonce;list readings;
// 8 registered UUID array;9 selected;10 reserved;11 reserved.
fresh(){S=header()+["[]",0,0,0]+outbox();}
list migrate(list v){return v;}
list nodes(){return llJson2List(sv(8));}
integer validSpecific(list v)
{
    list n=llJson2List(llList2String(v,8));if(llJsonValueType(llList2String(v,8),[])!=JSON_ARRAY || llGetListLength(n)>16)return FALSE;
    integer i;list seen=[];for(i=0;i<llGetListLength(n);++i){string k=llList2String(n,i);if(!uuid(k) || llListFindList(seen,[k])>=0)return FALSE;seen+=[k];}
    return whole(v,9,0,15) && (llGetListLength(n)==0 || llList2Integer(v,9)<llGetListLength(n)) && whole(v,10,0,0) && whole(v,11,0,0);
}
tick(float dt){}
integer reading(string id)
{integer i;for(i=0;i<llGetListLength(readings);i+=5)if(llList2String(readings,i)==id)return i;return -1;}
string summary()
{
    string t="Registered farm objects: "+(string)llGetListLength(nodes())+" / 16";
    if(llGetListLength(nodes())==0)return t+"\nAdd nearby same-owner root UUIDs.";
    string id=llList2String(nodes(),iv(9));integer i=reading(id);t+="\nNode "+(string)(iv(9)+1)+": "+id;
    if(i<0)return t+"\nAwaiting a reply; no current reading.";
    integer age=llGetUnixTime()-llList2Integer(readings,i+4);
    if(age>60)t+="\nSTALE: "+(string)age+" seconds old";
    return t+"\n"+llList2String(readings,i+1)+" | Locked "+llList2String(readings,i+3)+"\n"+llGetSubString(llList2String(readings,i+2),0,230);
}
list buttons(string p)
{if(p=="settings")return ["Pause","Resume","Back","Close"];return ["Add node","Next node","Remove node","Refresh","Details","Settings","Close"];}
string action(string c)
{
    if(page=="add")
    {
        page="main";if(!uuid(c) || c==(string)llGetKey() || !near((key)c,96.0) || llGetOwnerKey((key)c)!=llGetOwner() || llGetAgentSize((key)c)!=ZERO_VECTOR)return "Enter a nearby same-owner object root UUID.";
        list n=nodes();if(llGetListLength(n)>=16 || llListFindList(n,[c])>=0)return "Already registered or board full.";
        n+=[c];put(8,[llList2Json(JSON_ARRAY,n)]);put(9,[llGetListLength(n)-1]);polled=0;return "Node registered.";
    }
    if(c=="Add node"){page="add";return "";}
    if(c=="Next node" && llGetListLength(nodes())>0)put(9,[(iv(9)+1)%llGetListLength(nodes())]);
    if(c=="Remove node" && llGetListLength(nodes())>0)
    {put(8,[llList2Json(JSON_ARRAY,llDeleteSubList(nodes(),iv(9),iv(9)))]);put(9,[0]);readings=[];}
    if(c=="Refresh")polled=0;
    if(c=="Details"){integer i=reading(llList2String(nodes(),iv(9)));if(i>=0)return llList2String(readings,i+2);return "No reading.";}
    return "";
}
service()
{
    if(fault || iv(4) || llGetUnixTime()-polled<30)return;polled=llGetUnixTime();nonce=(string)llGenerateKey();
    string msg=llList2Json(JSON_OBJECT,["v",1,"op","QUERY","nonce",nonce]);integer i;
    for(i=0;i<llGetListLength(nodes());++i){key k=llList2Key(nodes(),i);if(near(k,96.0) && llGetOwnerKey(k)==llGetOwner())llRegionSayTo(k,DASH,msg);}
}
integer extraListen(integer c,key who,string msg)
{
    if(c!=DASH)return FALSE;
    if(fault || llStringLength(msg)>1000 || llGetUnixTime()-polled>30 || llListFindList(nodes(),[(string)who])<0 || !near(who,96.0) || llGetOwnerKey(who)!=llGetOwner())return TRUE;
    if(llJsonValueType(msg,[])!=JSON_OBJECT || llJsonGetValue(msg,["v"])!="1" || llJsonGetValue(msg,["op"])!="STATUS" || llJsonGetValue(msg,["nonce"])!=nonce)return TRUE;
    integer f=(integer)llJsonGetValue(msg,["fault"]);if(llListFindList(["0","1"],[llJsonGetValue(msg,["fault"])])<0)return TRUE;
    list r=[(string)who,llGetSubString(llJsonGetValue(msg,["kind"]),0,24),llGetSubString(llJsonGetValue(msg,["text"]),0,450),f,llGetUnixTime()];integer i=reading((string)who);
    if(i<0)readings+=r;else readings=llListReplaceList(readings,r,i,i+4);return TRUE;
}
integer credit(string kind,integer qty){return FALSE;}
string visual(){return llList2Json(JSON_OBJECT,["kind",KIND,"nodes",llGetListLength(nodes()),"fault",fault]);}
extraBoot(){}
extraLink(integer sender,integer number,string text,key id){}
integer textPage(string p){return p=="add";}
string textPrompt(){return "Paste a same-owner farm object's root UUID within 96 m.";}
transferAck(string kind,integer qty){}
// @include common.lslinc
