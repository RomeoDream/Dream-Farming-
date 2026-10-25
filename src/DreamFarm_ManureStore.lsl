// Romeo Dream - finite manure pit/tank with containment and separation.
// Materials use normalized RP quantities; no real nutrient/sanitation claims.
string DATA="dreamfarm:manurestore:v1";string KIND="MANURE STORE";
integer SCHEMA=1;integer OUT=18;integer BASE=23;
// 8 bag;9 capacity;10 covered;11 liner wear;12 spilled units;13 material age;
// 14 last agitation farm day;15 selected material;16 received units;17 catalog page.
// @include catalog.lslinc
// @include climate.lslinc
fresh(){S=header()+[emptyBag(),2000.0,1,0.0,0.0,0.0,-1.0,7,0.0,0]+outbox();alter("ENERGY",20.0);alter("PARTS",5.0);}
list migrate(list v){return v;}
integer validSpecific(list v)
{
    return validBag(llList2String(v,8)) && numeric(v,9,25.0,1000000.0) && whole(v,10,0,1) && numeric(v,11,0.0,100.0) && numeric(v,12,0.0,1000000.0) && numeric(v,13,0.0,1000000.0) && numeric(v,14,-1.0,1000000.0) && whole(v,15,0,30) && numeric(v,16,0.0,1000000.0) && whole(v,17,0,3) && totalStock()+iv(OUT+2)<=fv(9)+0.01;
}
tick(float dt)
{
    float waste=stock("MANURE")+stock("SLURRY")+stock("DIGESTATE");
    if(waste>0.0){put(13,[clamp(fv(13)+dt,0.0,1000000.0)]);put(11,[clamp(fv(11)+dt*0.1,0.0,100.0)]);}
    else put(13,[0.0]);
    if(!iv(10))
    {
        float rain=farmRain(fv(6))*4.0*dt;
        float caught=low(rain,clamp(fv(9)-totalStock()-iv(OUT+2),0.0,1000000.0));
        alter("WATER",caught);put(12,[clamp(fv(12)+rain-caught,0.0,1000000.0)]);
    }
    if(fv(11)>70.0)
    {
        float fraction=clamp((fv(11)-70.0)/30.0*0.02*dt,0.0,1.0);
        float water=stock("WATER")*fraction;float slurry=stock("SLURRY")*fraction;
        alter("WATER",-water);alter("SLURRY",-slurry);put(12,[clamp(fv(12)+water+slurry,0.0,1000000.0)]);
    }
}
string summary()
{return "Stored "+(string)totalStock()+" / "+(string)fv(9)+" | Reserved "+(string)iv(OUT+2)+"\nCovered "+(string)iv(10)+" | Liner wear "+(string)fv(11)+"%\nAge "+(string)fv(13)+" days | Spilled "+(string)fv(12)+" units\nSelected "+llList2String(LABELS,iv(15))+": "+(string)stock(llList2String(MATERIALS,iv(15)));}
list buttons(string p)
{
    if(p=="settings")return ["Destination","Pause","Resume","Normal","Demo x60","Back","Close"];
    if(p=="material")return materialButtons(iv(17));
    return ["Select material","Inventory","Send 10","Send 100","Cover","Agitate","Separate 10","Repair liner","Settings","Close"];
}
string action(string cmd)
{
    if(cmd=="Select material"){page="material";put(17,[0]);return "";}
    if(page=="material")
    {if(cmd=="Next"){put(17,[(iv(17)+1)%4]);return "";}integer i=llListFindList(LABELS,[cmd]);if(i>=0){put(15,[i]);page="main";return "Material selected.";}}
    if(cmd=="Inventory")return bagReport();
    if(cmd=="Cover"){put(10,[!iv(10)]);return "Rain cover toggled.";}
    if(cmd=="Agitate")
    {if(stock("SLURRY")<=0.0 || stock("ENERGY")<1.0)return "Need slurry and one local energy unit.";alter("ENERGY",-1.0);put(14,[fv(6)]);return "Slurry mixed; separation available for one farm day.";}
    if(cmd=="Separate 10")
    {
        if(stock("SLURRY")<10.0 || stock("ENERGY")<1.0 || fv(14)<0.0 || fv(6)-fv(14)>1.0)return "Need ten slurry, one energy and recent agitation.";
        alter("SLURRY",-10.0);alter("ENERGY",-1.0);alter("MANURE",3.0);alter("WATER",7.0);
        return "Ten slurry separated into three raw solids and seven water units. Solids still need composting; water is process water in this RP model.";
    }
    if(cmd=="Repair liner")
    {if(stock("PARTS")<1.0)return "Need one repair part.";alter("PARTS",-1.0);put(11,[0.0]);return "Liner repaired. Previously spilled material remains lost.";}
    if(cmd=="Send 10" || cmd=="Send 100")
    {
        integer q=10;if(cmd=="Send 100")q=100;string k=llList2String(MATERIALS,iv(15));
        if(stock(k)<q)return "Insufficient selected stock.";
        if(!startTransfer(k,q))return "Set a nearby same-owner destination and finish pending load.";
        alter(k,-q);return "Material reserved for delivery.";
    }
    return "";
}
integer credit(string kind,integer qty)
{
    if(llListFindList(["MANURE","BROWNS","SLURRY","DIGESTATE","WATER","ENERGY","PARTS"],[kind])<0 || totalStock()+iv(OUT+2)+qty>fv(9) || fv(16)+qty>1000000.0)return FALSE;
    if(llListFindList(["MANURE","SLURRY","DIGESTATE"],[kind])>=0)
    {float old=stock("MANURE")+stock("SLURRY")+stock("DIGESTATE");put(13,[fv(13)*old/(old+qty)]);if(kind=="SLURRY")put(14,[-1.0]);}
    alter(kind,qty);put(16,[fv(16)+qty]);return TRUE;
}
string visual(){return llList2Json(JSON_OBJECT,["kind",KIND,"stock",totalStock(),"covered",iv(10),"spill",fv(12),"fault",fault]);}
service(){sendTransfer();}
extraBoot(){}
integer extraListen(integer c,key who,string msg){return FALSE;}
extraLink(integer sender,integer number,string text,key id){}
integer textPage(string p){return FALSE;}
string textPrompt(){return "";}
transferAck(string kind,integer qty){}
// @include common.lslinc
