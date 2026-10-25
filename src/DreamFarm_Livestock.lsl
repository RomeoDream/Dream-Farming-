// One livestock pen per linkset. Edit SPECIES only on a new empty pen.
// Supported: Cattle, Chicken, Sheep, Pig. Starter stock is an adult female.
string SPECIES="Cattle";
string DATA="dreamfarm:livestock:v1";
string KIND="LIVESTOCK";
integer OUT=27;
integer BASE=32;
// 8 species;9 feed kg;10 water L;11 bedding kg;12 hunger;13 thirst;
// 14 health;15 cleanliness;16 stress;17 uncollected manure kg;
// 18 collected manure kg;19 produce units;20 pregnancy days (-1 none);
// 21 offspring count;22 adult age days;23 lactation days;24 lifetime manure;
// 25 roleplay purchase count;26 collected bedding waste kg;27..31 outbox.
integer speciesIndex(){return llListFindList(["Cattle","Chicken","Sheep","Pig"],[SPECIES]);}
float rate(integer k){return llList2Float([20.0,0.15,2.0,4.0],k);}
fresh()
{S=header()+[SPECIES,200.0,500.0,50.0,0.0,0.0,100.0,100.0,0.0,0.0,0.0,0.0,-1.0,0,730.0,30.0,0.0,0,0.0]+outbox();}
integer validSpecific(list v)
{
    if(speciesIndex()<0 || llList2String(v,8)!=SPECIES)return FALSE;
    integer i;for(i=9;i<=26;++i)if(i!=20 && !numeric(v,i,0.0,1000000.0))return FALSE;
    if(!numeric(v,20,-1.0,300.0))return FALSE;
    for(i=12;i<=16;++i)if(!numeric(v,i,0.0,100.0))return FALSE;
    return whole(v,21,0,1000000) && whole(v,25,0,1000000);
}
tick(float dt)
{
    if(fv(14)<=0.0)return;
    integer sp=speciesIndex();float need=rate(sp)*dt;
    float ate=low(fv(9),need);float drank=low(fv(10),need*3.0);
    put(9,[fv(9)-ate]);put(10,[fv(10)-drank]);
    float fed=0.0;float watered=0.0;if(need>0.0){fed=ate/need;watered=drank/(need*3.0);}
    put(12,[clamp(fv(12)+(1.0-fed)*30.0*dt-fed*20.0*dt,0.0,100.0)]);
    put(13,[clamp(fv(13)+(1.0-watered)*45.0*dt-watered*30.0*dt,0.0,100.0)]);
    float manure=ate*0.65;put(17,[clamp(fv(17)+manure,0.0,1000000.0)]);
    put(24,[clamp(fv(24)+manure,0.0,1000000.0)]);
    put(15,[clamp(fv(15)-dt*(4.0+low(fv(17),100.0)*0.08),0.0,100.0)]);
    float stress=(fv(12)+fv(13)+(100.0-fv(15)))/3.0;put(16,[stress]);
    float damage=clamp((stress-35.0)/8.0,0.0,12.0);
    put(14,[clamp(fv(14)+(1.5-damage)*dt,0.0,100.0)]);
    put(22,[clamp(fv(22)+dt,0.0,1000000.0)]);
    if(fv(14)<=0.0)return;
    float welfare=(fv(14)/100.0)*(1.0-stress/100.0)*fed*watered;
    float production=0.0;
    if(sp==0 && fv(23)>0.0){production=12.0;put(23,[clamp(fv(23)-dt,0.0,300.0)]);}
    if(sp==1)production=0.8;
    if(sp==2)production=0.06;
    put(19,[clamp(fv(19)+production*welfare*dt,0.0,1000000.0)]);
    if(fv(20)>=0.0)
    {
        put(20,[fv(20)+dt]);
        float gest=llList2Float([283.0,21.0,147.0,114.0],sp);
        if(fv(20)>=gest && iv(21)<999990)
        {
            integer litter=llList2Integer([1,4,2,8],sp);
            put(21,[iv(21)+litter]);put(20,[-1.0]);if(sp==0)put(23,[280.0]);
        }
    }
    // Milk/eggs in the pen spoil; wool does not. Produce is a local RP ledger.
    if(sp<2)put(19,[fv(19)*llPow(0.90,dt)]);
}
string summary()
{
    string status="Alive";if(fv(14)<=0.0)status="Dead - no production";
    string item=llList2String(["milk L","eggs","wool kg","(offspring only)"],speciesIndex());
    return SPECIES+" | "+status+"\nHealth "+(string)((integer)fv(14))+" | Clean "+(string)((integer)fv(15))+
      "\nFeed "+(string)((integer)fv(9))+" kg | Water "+(string)((integer)fv(10))+" L\nManure: pen "+(string)((integer)fv(17))+", collected "+(string)((integer)fv(18))+" kg"+
      "\nProduce "+(string)((integer)fv(19))+" "+item+" | Young "+(string)iv(21)+
      "\nDay "+(string)((integer)fv(6))+" | Pending load "+(string)iv(OUT+2)+" kg | Paused "+(string)iv(4);
}
list buttons(string p)
{
    if(p=="settings")return ["Destination","Pause","Resume","Normal","Demo x60","Back","Close"];
    return ["Feed 100","Water 200","Bedding 20","Muck out","Send manure","Send bedding","Breed","Collect produce","Send produce","Treat","Settings","Close"];
}
string action(string cmd)
{
    if(cmd=="Feed 100" || cmd=="Water 200" || cmd=="Bedding 20")
    {
        integer idx=9;float amount=100.0;if(cmd=="Water 200"){idx=10;amount=200.0;}if(cmd=="Bedding 20"){idx=11;amount=20.0;}
        if(fv(idx)+amount>1000000.0 || iv(25)>=1000000)return "Supply storage full.";
        put(idx,[fv(idx)+amount]);put(25,[iv(25)+1]);return "Roleplay delivery recorded. No money charged; server purchases come later.";
    }
    if(cmd=="Muck out")
    {
        if(fv(11)<2.0)return "Need 2 kg clean bedding.";
        if(fv(18)+fv(17)>1000000.0 || fv(26)>999998.0)return "Manure/bedding storage full.";
        put(18,[fv(18)+fv(17)]);put(17,[0.0]);put(11,[fv(11)-2.0]);put(26,[fv(26)+2.0]);put(15,[100.0]);
        return "Fresh manure collected separately from soiled bedding. Compost before garden application.";
    }
    if(cmd=="Send manure")
    {
        if(fv(18)<10.0)return "Collect at least 10 kg manure first.";
        if(!startTransfer("MANURE",10))return "Set nearby same-owner compost destination; finish any pending delivery.";
        put(18,[fv(18)-10.0]);return "10 kg reserved and saved for compost delivery.";
    }
    if(cmd=="Send bedding")
    {
        if(fv(26)<2.0)return "Muck out first to collect used bedding.";
        if(!startTransfer("BROWNS",2))return "Set nearby compost destination or finish pending delivery.";
        put(26,[fv(26)-2.0]);return "2 kg used bedding reserved for compost delivery.";
    }
    if(cmd=="Breed")
    {
        if(fv(14)<80.0 || fv(16)>20.0 || fv(20)>=0.0)return "Breeding requires good health, low stress and no active pregnancy/incubation.";
        put(20,[0.0]);return "Roleplay breeding service started. Young are recorded, not rezzed. Chickens use incubation time.";
    }
    if(cmd=="Send produce")
    {
        integer sp=speciesIndex();if(sp==3)return "Pigs produce offspring; no packaged produce.";
        if(fv(19)<1.0)return "No whole produce unit available.";
        string k=llList2String(["MILK","EGGS","WOOL"],sp);
        if(!startTransfer(k,1))return "Set a nearby storage/processor destination.";
        put(19,[fv(19)-1.0]);return "One produce unit reserved for delivery.";
    }
    if(cmd=="Collect produce")
    {
        integer qty=(integer)fv(19);put(19,[fv(19)-(float)qty]);return "Collected/consumed "+(string)qty+" local produce units for roleplay. No inventory item delivered.";
    }
    if(cmd=="Treat")
    {if(fv(14)<=0.0)return "Cannot revive a dead animal.";put(14,[clamp(fv(14)+15.0,0.0,100.0)]);return "Roleplay veterinary care applied. Feed, water and clean the pen too.";}
    return "";
}
integer credit(string kind,integer qty)
{
    integer i=-1;if(kind=="FEED" || kind=="HAY" || kind=="SILAGE")i=9;
    if(kind=="WATER")i=10;if(kind=="BEDDING" || kind=="BROWNS")i=11;
    if(i<0 || fv(i)+qty>1000000.0)return FALSE;put(i,[fv(i)+qty]);return TRUE;
}
string visual(){return llList2Json(JSON_OBJECT,["kind",KIND,"health",fv(14),"manure",fv(17),"fault",fault]);}
extraBoot(){}
integer extraListen(integer c,key who,string msg){return FALSE;}
service(){sendTransfer();}
integer SCHEMA=1;
list migrate(list v){return v;}
integer textPage(string p){return FALSE;}
string textPrompt(){return "";}
extraLink(integer sender,integer number,string text,key id){}
transferAck(string kind,integer qty){}
// @include common.lslinc
