// Individual animals with persistent identities, pedigree and growing young.
// One controller manages up to eight records. Visual animal meshes are separate.
string DATA="dreamfarm:herd:v1";string KIND="HERD";
integer SCHEMA=1;integer OUT=23;integer BASE=28;
// 8 inventory;9 animal JSON strings;10 selected animal;11 grazing;
// 12 births;13 purchased animals;14 reserved;15 cleanliness;16 reserved;
// 17 lifetime manure;18 selected export material;19 catalog page;20 deaths;
// 21 maximum animals;22 reserved;23..27 outbox.
// Animal: id,name,species,sex,age,weight,health,hunger,thirst,stress,due,
// sire,dam,genetic,lactation,alive,mateID,mateGenetic. sex 0 male,1 female.
list SPECIES=["Cattle","Chicken","Sheep","Pig","Horse","Donkey"];
list MATURE=[540.0,150.0,365.0,240.0,1095.0,1095.0];
list ADULT_WEIGHT=[600.0,2.5,70.0,180.0,450.0,250.0];
list GESTATION=[283.0,21.0,147.0,114.0,340.0,365.0];
// @include catalog.lslinc
integer countAnimals(){return llGetListLength(llJson2List(sv(9)));}
list animal(integer i){return llJson2List(llList2String(llJson2List(sv(9)),i));}
putAnimal(integer i,list a)
{list herd=llJson2List(sv(9));herd=llListReplaceList(herd,[llList2Json(JSON_ARRAY,a)],i,i);put(9,[llList2Json(JSON_ARRAY,herd)]);}
appendAnimal(list a)
{list herd=llJson2List(sv(9));herd+=[llList2Json(JSON_ARRAY,a)];put(9,[llList2Json(JSON_ARRAY,herd)]);}
list makeAnimal(integer sp,integer sex,float age,string sire,string dam,float genes)
{
    string id=(string)llGenerateKey();string name=llList2String(SPECIES,sp)+" "+llGetSubString(id,0,5);
    float lact=0.0;if(sp==0 && sex==1 && age>=llList2Float(MATURE,sp))lact=30.0;
    float weight=llList2Float(ADULT_WEIGHT,sp)*clamp(age/llList2Float(MATURE,sp),0.05,1.0)*genes;
    return [id,name,sp,sex,age,weight,100.0,0.0,0.0,0.0,-1.0,sire,dam,genes,lact,1,"",1.0];
}
fresh(){S=header()+[emptyBag(),"[]",0,0,0,0,0,100.0,0,0.0,0,0,0,8,0]+outbox();}
list migrate(list v){return v;}
integer validSpecific(list v)
{
    if(!validBag(llList2String(v,8)) || llJsonValueType(llList2String(v,9),[])!=JSON_ARRAY)return FALSE;
    list herd=llJson2List(llList2String(v,9));if(llGetListLength(herd)>8)return FALSE;
    list ids=[];integer i;integer j;
    for(i=0;i<llGetListLength(herd);++i)
    {
        list a=llJson2List(llList2String(herd,i));
        if(llGetListLength(a)!=18 || !uuid(llList2String(a,0)) || llListFindList(ids,[llList2String(a,0)])>=0)return FALSE;
        ids+=[llList2String(a,0)];
        if(llGetListEntryType(a,1)!=TYPE_STRING || llStringLength(llList2String(a,1))>24)return FALSE;
        if(!whole(a,2,0,5) || !whole(a,3,0,1) || !whole(a,15,0,1))return FALSE;
        for(j=4;j<=9;++j)if(!numeric(a,j,0.0,1000000.0))return FALSE;
        for(j=6;j<=9;++j)if(!numeric(a,j,0.0,100.0))return FALSE;
        if(!numeric(a,10,-1.0,1000000.0) || !numeric(a,13,0.8,1.2) || !numeric(a,14,0.0,300.0) || !numeric(a,17,0.8,1.2))return FALSE;
        for(j=11;j<=12;++j)if(llList2String(a,j)!="" && !uuid(llList2String(a,j)))return FALSE;
        if(llList2String(a,16)!="" && !uuid(llList2String(a,16)))return FALSE;
        if(llList2Float(a,10)>=0.0 && !uuid(llList2String(a,16)))return FALSE;
    }
    if(!whole(v,10,0,7) || (llGetListLength(herd)>0 && llList2Integer(v,10)>=llGetListLength(herd)) || !whole(v,11,0,1))return FALSE;
    for(i=12;i<=22;++i)if(!numeric(v,i,0.0,1000000.0))return FALSE;
    return whole(v,12,0,1000000) && whole(v,13,0,1000000) && numeric(v,15,0.0,100.0) && whole(v,18,0,30) && whole(v,19,0,3) && whole(v,20,0,1000000) && whole(v,21,8,8);
}
float need(list a)
{integer sp=llList2Integer(a,2);return llList2Float([20.0,0.15,2.0,4.0,10.0,6.0],sp)*clamp(llList2Float(a,4)/llList2Float(MATURE,sp),0.1,1.0);}
tick(float dt)
{
    integer n=countAnimals();integer i;float demand=0.0;
    for(i=0;i<n;++i){list a=animal(i);if(llList2Integer(a,15))demand+=need(a)*dt;}
    if(demand<=0.0)return;
    float grass=0.0;if(iv(11))grass=low(stock("GRASS"),demand);
    float feed=low(stock("FEED"),demand-grass);float water=low(stock("WATER"),demand*3.0);
    alter("GRASS",-grass);alter("FEED",-feed);alter("WATER",-water);
    float fed=(grass+feed)/demand;float drank=water/(demand*3.0);
    put(15,[clamp(fv(15)-dt*(2.0+n),0.0,100.0)]);
    for(i=0;i<n;++i)
    {
        list a=animal(i);if(llList2Integer(a,15))
        {
            integer sp=llList2Integer(a,2);float age=llList2Float(a,4)+dt;
            float hunger=clamp(llList2Float(a,7)+dt*((1.0-fed)*30.0-fed*20.0),0.0,100.0);
            float thirst=clamp(llList2Float(a,8)+dt*((1.0-drank)*45.0-drank*30.0),0.0,100.0);
            float stress=(hunger+thirst+(100.0-fv(15)))/3.0;
            float health=clamp(llList2Float(a,6)+dt*(1.0-clamp((stress-30.0)/6.0,0.0,15.0)),0.0,100.0);
            float weight=llList2Float(ADULT_WEIGHT,sp)*clamp(age/llList2Float(MATURE,sp),0.05,1.0)*llList2Float(a,13)*(0.7+0.3*health/100.0);
            a=llListReplaceList(a,[age,weight,health,hunger,thirst,stress],4,9);
            float manure=need(a)*dt*fed*0.65;alter("MANURE",low(manure,1000000.0-stock("MANURE")));put(17,[clamp(fv(17)+manure,0.0,1000000.0)]);
            if(health<=0.0){a=llListReplaceList(a,[0],15,15);put(20,[iv(20)+1]);}
            else
            {
                float welfare=health/100.0*(1.0-stress/100.0)*fed*drank*llList2Float(a,13);
                float lact=clamp(llList2Float(a,14)-dt,0.0,300.0);a=llListReplaceList(a,[lact],14,14);
                if(age>=llList2Float(MATURE,sp))
                {
                    if(sp==0 && llList2Integer(a,3)==1 && lact>0.0)alter("MILK",low(12.0*welfare*dt,1000000.0-stock("MILK")));
                    if(sp==1 && llList2Integer(a,3)==1)alter("EGGS",low(0.8*welfare*dt,1000000.0-stock("EGGS")));
                    if(sp==2)alter("WOOL",low(0.06*welfare*dt,1000000.0-stock("WOOL")));
                }
                float due=llList2Float(a,10);integer litter=llList2Integer([1,4,2,4,1,1],sp);
                if(due>=0.0 && fv(6)+dt>=due && countAnimals()+litter<=8 && iv(12)<=1000000-litter)
                {
                    integer k;for(k=0;k<litter;++k)
                    {
                        float genes=clamp((llList2Float(a,13)+llList2Float(a,17))/2.0+llFrand(0.1)-0.05,0.8,1.2);
                        appendAnimal(makeAnimal(sp,(integer)llFrand(2.0),0.0,llList2String(a,16),llList2String(a,0),genes));
                    }
                    a=llListReplaceList(a,[-1.0],10,10);a=llListReplaceList(a,[280.0],14,14);put(12,[iv(12)+litter]);
                }
            }
            putAnimal(i,a);
        }
    }
    alter("MILK",-stock("MILK")*(1.0-llPow(0.9,dt)));alter("EGGS",-stock("EGGS")*(1.0-llPow(0.98,dt)));
}
string summary()
{
    string text="Animals "+(string)countAnimals()+" / 8 | Births "+(string)iv(12)+"\nFeed "+(string)stock("FEED")+" | Water "+(string)stock("WATER")+" | Clean "+(string)((integer)fv(15));
    if(countAnimals()>0)
    {list a=animal(iv(10));text+="\n"+llList2String(a,1)+" | "+llList2String(SPECIES,llList2Integer(a,2))+" | Sex "+llList2String(["M","F"],llList2Integer(a,3))+"\nAge "+(string)((integer)llList2Float(a,4))+" d | Health "+(string)((integer)llList2Float(a,6))+" | Due day "+(string)llList2Float(a,10);}
    return text;
}
list buttons(string p)
{
    if(p=="settings")return ["Destination","Pause","Resume","Normal","Demo x60","Sandbox supplies","Back","Close"];
    if(p=="animals"){list b=[];integer i;for(i=0;i<countAnimals();++i)b+=["Animal "+(string)(i+1)];return b+["Back","Close"];}
    if(p=="manage")return ["Cow","Bull","Hen","Rooster","Ewe","Ram","Sow","Boar","Equines","Remove dead","Back","Close"];
    if(p=="equines")return ["Mare","Stallion","Jenny","Jack","Back","Close"];
    if(p=="material")return materialButtons(iv(19));
    if(p=="export")return ["Select material","Send 1","Send 10","Back","Close"];
    return ["Animals","Inventory","Breed","Rename","Muck out","Treat","Grazing","Export","Manage","Settings","Close"];
}
integer related(list a,list b)
{
    if(llList2String(a,0)==llList2String(b,11) || llList2String(a,0)==llList2String(b,12) || llList2String(b,0)==llList2String(a,11) || llList2String(b,0)==llList2String(a,12))return TRUE;
    if(llList2String(a,11)!="" && llList2String(a,11)==llList2String(b,11))return TRUE;
    if(llList2String(a,12)!="" && llList2String(a,12)==llList2String(b,12))return TRUE;return FALSE;
}
string action(string cmd)
{
    if(page=="rename")
    {if(llStringLength(cmd)<1 || llStringLength(cmd)>24)return "Name must contain 1-24 characters.";list a=animal(iv(10));a=llListReplaceList(a,[cmd],1,1);putAnimal(iv(10),a);page="main";return "Animal named.";}
    if(cmd=="Animals"){page="animals";return "";}if(cmd=="Manage"){page="manage";return "";}if(cmd=="Equines" && page=="manage"){page="equines";return "";}
    if(cmd=="Export"){page="export";return "";}if(cmd=="Select material"){page="material";put(19,[0]);return "";}
    if(page=="material")
    {if(cmd=="Next"){put(19,[(iv(19)+1)%4]);return "";}integer n=llListFindList(LABELS,[cmd]);if(n>=0){put(18,[n]);page="export";return "";}}
    if(page=="animals" && llSubStringIndex(cmd,"Animal ")==0)
    {integer i=(integer)llGetSubString(cmd,7,-1)-1;if(i>=0 && i<countAnimals())put(10,[i]);page="main";return "Selected animal.";}
    integer add=llListFindList(["Cow","Bull","Hen","Rooster","Ewe","Ram","Sow","Boar","Mare","Stallion","Jenny","Jack"],[cmd]);
    if((page=="manage" && add>=0 && add<8) || (page=="equines" && add>=8))
    {if(countAnimals()>=8 || iv(13)>=1000000)return "Herd capacity reached.";integer sp=add/2;appendAnimal(makeAnimal(sp,1-add%2,llList2Float(MATURE,sp)+30.0,"","",1.0));put(13,[iv(13)+1]);return "SANDBOX adult added; no bank payment claimed.";}
    if(cmd=="Sandbox supplies")
    {if(totalStock()+700.0>1000000.0)return "Supplies full.";alter("FEED",200.0);alter("WATER",400.0);alter("BEDDING",50.0);alter("MEDICINE",50.0);return "SANDBOX feed, water, bedding and medicine delivered.";}
    if(cmd=="Remove dead")
    {list herd=[];integer k;for(k=0;k<countAnimals();++k){list a=animal(k);if(llList2Integer(a,15))herd+=[llList2Json(JSON_ARRAY,a)];}put(9,[llList2Json(JSON_ARRAY,herd)]);put(10,[0]);return "Dead records removed from this active pen. No meat or economic credit created.";}
    if(cmd=="Inventory")return bagReport();
    if(cmd=="Muck out")
    {if(stock("BEDDING")<2.0 || stock("BROWNS")>999998.0)return "Need two bedding units and storage room.";alter("BEDDING",-2.0);alter("BROWNS",2.0);put(15,[100.0]);return "Pen cleaned; used bedding retained.";}
    if(cmd=="Grazing"){put(11,[!iv(11)]);return "Grazing toggled; consumes delivered grass before mixed feed.";}
    if(cmd=="Send 1" || cmd=="Send 10")
    {integer q=1;if(cmd=="Send 10")q=10;string k=llList2String(MATERIALS,iv(18));if(stock(k)<q)return "Not enough stock.";if(!startTransfer(k,q))return "Set destination or finish pending load.";alter(k,-q);return "Animal product/supply reserved for delivery.";}
    if(countAnimals()==0)return "Add an animal first.";
    list selected=animal(iv(10));
    if(cmd=="Rename"){page="rename";return "";}
    if(cmd=="Treat")
    {if(!llList2Integer(selected,15) || stock("MEDICINE")<1.0)return "Needs a living animal and one medicine unit.";alter("MEDICINE",-1.0);selected=llListReplaceList(selected,[clamp(llList2Float(selected,6)+20.0,0.0,100.0)],6,6);putAnimal(iv(10),selected);return "Roleplay treatment consumed medicine.";}
    if(cmd=="Breed")
    {
        integer sp=llList2Integer(selected,2);
        if(!llList2Integer(selected,15) || llList2Integer(selected,3)!=1 || llList2Float(selected,4)<llList2Float(MATURE,sp) || llList2Float(selected,6)<80.0 || llList2Float(selected,9)>20.0 || llList2Float(selected,10)>=0.0)return "Select a healthy adult female not already pregnant/incubating.";
        integer i;for(i=0;i<countAnimals();++i)
        {
            list male=animal(i);
            if(llList2Integer(male,15) && llList2Integer(male,3)==0 && llList2Integer(male,2)==sp && llList2Float(male,4)>=llList2Float(MATURE,sp) && llList2Float(male,6)>=80.0 && llList2Float(male,9)<=20.0 && !related(selected,male))
            {selected=llListReplaceList(selected,[fv(6)+llList2Float(GESTATION,sp)],10,10);selected=llListReplaceList(selected,[llList2String(male,0),llList2Float(male,13)],16,17);putAnimal(iv(10),selected);return "Breeding recorded with sire identity. Birth waits for sufficient pen capacity.";}
        }
        return "No suitable unrelated adult male of the same species.";
    }
    return "";
}
integer credit(string kind,integer qty)
{if(llListFindList(["FEED","WATER","BEDDING","GRASS","MEDICINE"],[kind])<0 || stock(kind)+qty>1000000.0)return FALSE;alter(kind,qty);return TRUE;}
string visual(){return llList2Json(JSON_OBJECT,["kind",KIND,"animals",countAnimals(),"selected",iv(10),"fault",fault]);}
extraBoot(){llListen(-918248,"",NULL_KEY,"");}
integer extraListen(integer c,key who,string msg)
{
    if(c!=-918248)return FALSE;
    if(llGetOwnerKey(who)!=llGetOwner())return TRUE;
    list info=llGetObjectDetails(who,[OBJECT_POS]);
    if(llGetListLength(info)<1 || llVecDist(llGetPos(),llList2Vector(info,0))>96.0)return TRUE;
    if(llJsonGetValue(msg,["type"])!="EQUINE_CHECK")return TRUE;
    string id=llJsonGetValue(msg,["animal"]);
    string nonce=llJsonGetValue(msg,["nonce"]);
    if(llStringLength(nonce)>64 || llStringLength(nonce)<8)return TRUE;
    integer i;integer found=FALSE;
    for(i=0;i<countAnimals();++i)
    {
        list a=animal(i);
        integer sp=llList2Integer(a,2);
        if(llList2String(a,0)==id && (sp==4 || sp==5) && llList2Integer(a,15))found=TRUE;
    }
    llRegionSayTo(who,-918248,llList2Json(JSON_OBJECT,["type","EQUINE_RESULT","animal",id,"nonce",nonce,"valid",found]));
    return TRUE;
}
extraLink(integer sender,integer number,string text,key id){}
integer textPage(string p){return p=="rename";}
string textPrompt(){return "Name the selected animal (1-24 characters).";}
service(){sendTransfer();}
transferAck(string kind,integer qty){}
// @include common.lslinc
