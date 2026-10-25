string DATA="dreamfarm:field:v1";
string KIND="FIELD";
integer OUT=50;
integer BASE=55;
list CROPS=["Wheat","Corn","Soybean","Potato","Sunflower","Grass"];
list GDD=[300.0,450.0,350.0,280.0,320.0,100.0];
list BASE_TEMP=[0.0,10.0,8.0,5.0,6.0,2.0];
list YIELD=[30.0,45.0,25.0,60.0,20.0,40.0];
// Each field is a normalized RP production plot, not a real hectare prediction.
// 8 crop(0 empty,1..6);9 tilled;10 thermal growth;11 health;12 water%;
// 13 N;14 P;15 K;16 pH;17 OM%;18 compaction%;19 weeds;20 pests;21 disease;
// 22 ripe days;23 prior crop;24 seed units;25 water tank L;26 fertilizer kg;
// 27 mature compost kg;28 diesel L;29 equipment wear;30 greenhouse;
// 31 auto irrigation;32 energy kWh;33 climate power;34..39 local crop kg;
// 40 crop residue kg;41 harvest count;42 spoilage kg;43 coverage JSON;
// 44 soil type;45 seed vigor%;46 sowing-window rules;47 reserved moisture;
// 48 completed machine jobs;49 reserved;50..54 outbox. Schema 1 migrates atomically.
fresh()
{S=header()+[0,0,0.0,100.0,60.0,65.0,65.0,65.0,6.5,4.0,25.0,0.0,0.0,0.0,0.0,0,12,1000.0,20.0,0.0,50.0,0.0,0,0,100.0,0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0,0.0]+["",0,100.0,0,20.0,0,0]+outbox();}
integer validSpecific(list v)
{
    integer i;for(i=8;i<43;++i)if(!numeric(v,i,0.0,1000000.0))return FALSE;
    if(!whole(v,8,0,6) || !whole(v,9,0,1) || !whole(v,23,0,6) || !whole(v,24,0,1000000))return FALSE;
    for(i=11;i<=21;++i)if(!numeric(v,i,0.0,100.0))return FALSE;
    if(!numeric(v,16,0.0,14.0) || !numeric(v,17,0.0,20.0) || !numeric(v,29,0.0,100.0))return FALSE;
    for(i=30;i<=31;++i)if(!whole(v,i,0,1))return FALSE;
    return whole(v,33,0,1) && whole(v,41,0,1000000) && workValid(llList2String(v,43)) && whole(v,44,0,2) && numeric(v,45,0.0,100.0) && whole(v,46,0,1) && numeric(v,47,0.0,100.0) && whole(v,48,0,1000000) && whole(v,49,0,0);
}
// Identical farm-day zero across independently installed fields is optional:
// a fresh object begins its own 120-day temperate year in spring.
float temperature(float day)
{return 12.0+14.0*llSin(6.2831853*(day-5.0)/120.0)+3.0*llSin(day*2.1);}
float rain(float day)
{if(llSin(day*1.713)+llSin(day*0.391)>0.65)return 12.0;return 0.0;}
integer stage()
{
    if(iv(8)==0)return 0;if(fv(11)<=0.0)return 5;
    float p=fv(10)/llList2Float(GDD,iv(8)-1);
    if(p>=1.0)return 4;if(p>=0.6)return 3;if(p>=0.2)return 2;return 1;
}
tick(float dt)
{
    float temp=temperature(fv(6));float rainfall=rain(fv(6));
    float light=clamp(0.65+0.3*llSin(6.2831853*(fv(6)-5.0)/120.0),0.15,1.0);
    if(iv(30))
    {
        rainfall=0.0;temp+=5.0;light*=0.75;
        if(iv(33) && ((!USE_DPC && fv(32)>=2.0*dt) || gridLive())){if(!USE_DPC)put(32,[fv(32)-2.0*dt]);temp=22.0;light=0.9;}
    }
    // Water balance, drainage and nutrient leaching continue on bare fields.
    float retention=llList2Float([1.0,0.7,1.5],iv(44));
    float w=fv(12)+rainfall*dt-retention*clamp(2.0+temp*0.12,0.5,8.0)*dt;
    if(w>85.0){put(13,[clamp(fv(13)-(w-85.0)*dt*0.05,0.0,100.0)]);w-=dt*(w-85.0)*0.4;}
    put(12,[clamp(w,0.0,100.0)]);
    if(iv(31) && fv(12)<50.0)
    {
        float water=low(fv(25),20.0*dt);put(25,[fv(25)-water]);put(12,[clamp(fv(12)+water*0.5,0.0,100.0)]);
    }
    put(19,[clamp(fv(19)+dt*clamp(temp/10.0,0.0,3.0),0.0,100.0)]);
    if(iv(8)>0 && fv(11)>0.0)
    {
        integer crop=iv(8)-1;
        float moisture=clamp((fv(12)-8.0)/35.0,0.0,1.0)*clamp((100.0-fv(12))/15.0,0.0,1.0);
        float nutrient=clamp(low(fv(13),low(fv(14),fv(15)))/35.0,0.0,1.0);
        float ph=clamp(1.0-llFabs(fv(16)-6.5)/2.0,0.0,1.0);
        float efficiency=moisture*nutrient*ph*light*(fv(45)/100.0)*(1.0-fv(18)*0.006)*(1.0-fv(19)*0.008);
        put(20,[clamp(fv(20)+dt*(temp/20.0-0.4),0.0,100.0)]);
        put(21,[clamp(fv(21)+dt*(fv(12)/40.0-1.0+fv(20)/100.0),0.0,100.0)]);
        efficiency*=clamp(1.0-(fv(20)+fv(21))/160.0,0.0,1.0);
        float stress=(1.0-moisture)*5.0+fv(21)*0.03;
        if(temp<0.0)stress+=llFabs(temp)*2.0;
        if(temp>35.0)stress+=(temp-35.0)*2.0;
        put(11,[clamp(fv(11)+(0.5-stress)*dt,0.0,100.0)]);
        float target=llList2Float(GDD,crop);
        if(fv(10)<target)
        {
            float growth=clamp(temp-llList2Float(BASE_TEMP,crop),0.0,30.0)*efficiency*dt;
            if(fv(11)<=0.0)growth=0.0;
            put(10,[low(target,fv(10)+growth)]);
            put(13,[clamp(fv(13)-growth*0.04,0.0,100.0)]);
            put(14,[clamp(fv(14)-growth*0.02,0.0,100.0)]);
            put(15,[clamp(fv(15)-growth*0.03,0.0,100.0)]);
            if(crop==2)put(13,[clamp(fv(13)+dt*0.25,0.0,100.0)]);
        }
        else
        {put(22,[fv(22)+dt]);if(fv(22)>3.0)put(11,[clamp(fv(11)-dt*5.0,0.0,100.0)]);}
    }
    // Storage is dry ambient; potatoes spoil faster. No fake cold-chain connection.
    integer i;for(i=34;i<=39;++i)
    {
        float loss=0.002;if(i==37)loss=0.02;if(i==39)loss=0.03;
        float spoiled=fv(i)*(1.0-llPow(1.0-loss,dt));
        put(i,[clamp(fv(i)-spoiled,0.0,1000000.0)]);put(42,[clamp(fv(42)+spoiled,0.0,1000000.0)]);
    }
}
// @include power.lslinc
// @include field_work.lslinc
string summary()
{
    string c="Empty";if(iv(8)>0)c=llList2String(CROPS,iv(8)-1);
    return c+" | stage "+(string)stage()+" | health "+(string)((integer)fv(11))+"%\nWater "+(string)((integer)fv(12))+"% | N/P/K "+(string)((integer)fv(13))+"/"+(string)((integer)fv(14))+"/"+(string)((integer)fv(15))+
    "\npH "+(string)fv(16)+" | Weeds "+(string)((integer)fv(19))+" | Diesel "+(string)((integer)fv(28))+" L"+
    "\nCompost "+(string)((integer)fv(27))+" kg | Seed "+(string)iv(24)+" | Thermal growth "+(string)((integer)fv(10))+
    "\nDay "+(string)((integer)fv(6))+" | "+(string)((integer)temperature(fv(6)))+" C | Paused "+(string)iv(4);
}
list buttons(string p)
{
    if(p=="clear")return ["Confirm clear","Back","Close"];
    if(p=="settings")return ["Pause","Resume","Normal","Demo x60","Destination","Back","Close"];
    if(p=="plant")return CROPS+["Back","Close"];
    if(p=="export")return CROPS+["Back","Close"];
    if(p=="storage")return CROPS+["Back","Close"];
    if(p=="soil")return ["Water","Fertilize","Compost","Lime","Weed","Treat pests","Clear crop","Send residue","Back","Close"];
    if(p=="soiltype")return ["Loam","Clay","Sand","Season rules","Soil test","Reset coverage","Back","Close"];
    if(p=="utility")return ["Greenhouse","Auto water","Climate power","Refill supplies","Service","Storage","Field setup","Back","Close"];
    return ["Plow","Plant","Harvest","Soil care","Utilities","Export harvest","Settings","Close"];
}
integer machine(float liters)
{if(remoteWork)return TRUE;if(fv(28)<liters || fv(29)>95.0)return FALSE;put(28,[fv(28)-liters]);put(29,[clamp(fv(29)+2.0,0.0,100.0)]);return TRUE;}
string action(string cmd)
{
    if(cmd=="Field setup"){page="soiltype";return "";}
    if(cmd=="Season rules"){put(46,[!iv(46)]);return "Sowing window enforcement toggled.";}
    if(cmd=="Reset coverage"){put(43,[""]);return "Coverage cleared; crop and supplies preserved.";}
    if(cmd=="Soil test")return summary()+" | Organic matter "+(string)fv(17)+" | Compaction "+(string)fv(18)+" | Seed quality "+(string)fv(45);
    integer soil=llListFindList(["Loam","Clay","Sand"],[cmd]);if(page=="soiltype" && soil>=0){put(44,[soil]);return "Soil profile selected.";}
    if(cmd=="Plant"){page="plant";return "";}
    if(cmd=="Soil care"){page="soil";return "";}
    if(cmd=="Utilities"){page="utility";return "";}
    if(cmd=="Export harvest"){page="export";return "Choose a crop to send 10 units. Grain exports as wet grain for drying.";}
    integer crop=llListFindList(CROPS,[cmd]);
    if(page=="export" && crop>=0)
    {
        if(fv(34+crop)<10.0)return "Need 10 units of harvested crop.";
        string k=llList2String(["WET_WHEAT","WET_CORN","SOYBEAN","POTATO","SUNFLOWER","GRASS"],crop);
        if(!startTransfer(k,10))return "Set nearby destination or finish pending load.";
        put(34+crop,[fv(34+crop)-10.0]);return "Harvest reserved for storage or processing.";
    }
    if(page=="storage" && crop>=0)
    {
        if(fv(34+crop)<1.0)return "None of that crop remains in storage.";
        put(34+crop,[fv(34+crop)-1.0]);return "Used 1 kg "+cmd+" for roleplay. No inventory object sent.";
    }
    if(page=="plant" && crop>=0)
    {
        if(iv(8)>0 || !iv(9) || iv(24)<1)return "Need an empty tilled field and one seed unit.";
        integer season=((integer)(fv(6)/30.0))%4;
        if(iv(46) && !iv(30) && (season==3 || (season==2 && crop!=0 && crop!=5)))return "Outside this crop sowing window. Use greenhouse or wait for season.";
        if(!machine(0.5))return "Need diesel or equipment service.";
        put(8,[crop+1]);put(24,[iv(24)-1]);put(10,[0.0]);put(11,[100.0]);put(22,[0.0]);
        // Repeat cropping carries extra soil disease; rotation avoids the penalty.
        if(iv(23)==crop+1)put(21,[clamp(fv(21)+20.0,0.0,100.0)]);
        page="main";return "Planted "+cmd+". Weather, soil and care now control growth.";
    }
    if(cmd=="Plow")
    {if(iv(8)>0)return "Clear or harvest first.";if(!machine(2.0))return "Need diesel or service.";put(9,[1]);put(18,[10.0]);put(19,[0.0]);put(17,[clamp(fv(17)-0.1,0.0,20.0)]);return "Soil tilled; compaction and weeds reduced; organic matter slightly lost.";}
    if(cmd=="Harvest")
    {
        if(stage()!=4)return "No healthy mature crop.";
        integer i=iv(8)-1;float amount=llList2Float(YIELD,i)*fv(11)/100.0;
        if(fv(34+i)+amount>1000000.0 || fv(40)+amount*0.3>1000000.0 || iv(41)>=1000000 || iv(24)>=999998)return "Storage full.";
        if(!machine(2.0))return "Need diesel or service.";
        put(34+i,[fv(34+i)+amount]);put(40,[fv(40)+amount*0.3]);put(24,[iv(24)+2]);put(41,[iv(41)+1]);put(23,[iv(8)]);
        put(8,[0]);put(9,[0]);put(10,[0.0]);put(22,[0.0]);put(18,[clamp(fv(18)+12.0,0.0,100.0)]);
        return "Harvest saved: "+(string)amount+" kg, two seed units and crop residue. Clear field and credits saved together.";
    }
    if(cmd=="Clear crop"){page="clear";return "Clear crop destroys the current planting. Choose Confirm clear.";}
    if(cmd=="Confirm clear"){put(8,[0]);put(10,[0.0]);put(9,[0]);put(22,[0.0]);page="main";return "Crop removed; saved produce preserved.";}
    if(cmd=="Water")
    {if(fv(25)<20.0)return "Water tank empty.";put(25,[fv(25)-20.0]);put(12,[clamp(fv(12)+10.0,0.0,100.0)]);return "20 L irrigated. Waterlogging also harms roots.";}
    if(cmd=="Fertilize" || cmd=="Compost")
    {
        integer idx=26;if(cmd=="Compost")idx=27;
        if(fv(idx)<2.0)return "Need 2 kg fertilizer or delivered mature compost.";
        put(idx,[fv(idx)-2.0]);integer k;for(k=13;k<=15;++k)put(k,[clamp(fv(k)+15.0,0.0,100.0)]);
        if(idx==27)put(17,[clamp(fv(17)+0.5,0.0,20.0)]);
        if(fv(13)>90.0)put(11,[clamp(fv(11)-10.0,0.0,100.0)]);
        return "Nutrients added. Excess fertility can damage the crop.";
    }
    if(cmd=="Lime"){if(fv(26)<1.0)return "Need one amendment unit.";put(26,[fv(26)-1.0]);put(16,[clamp(fv(16)+0.3,0.0,14.0)]);return "Lime raised pH; check before adding more.";}
    if(cmd=="Weed"){put(19,[0.0]);return "Weeds removed by hand.";}
    if(cmd=="Treat pests"){put(20,[clamp(fv(20)-40.0,0.0,100.0)]);put(21,[clamp(fv(21)-20.0,0.0,100.0)]);return "Roleplay pest management applied.";}
    if(cmd=="Greenhouse"){put(30,[!iv(30)]);return "Greenhouse cover toggled. Construction is roleplay; only climate state changes.";}
    if(cmd=="Auto water"){put(31,[!iv(31)]);return "Automatic irrigation toggled; it consumes your water tank.";}
    if(cmd=="Climate power"){put(33,[!iv(33)]);return "Greenhouse conditioning toggled; consumes local energy credit.";}
    if(cmd=="Refill supplies")
    {if(iv(24)<12)put(24,[12]);if(fv(25)<1000.0)put(25,[1000.0]);if(fv(26)<20.0)put(26,[20.0]);if(fv(28)<50.0)put(28,[50.0]);if(fv(32)<100.0)put(32,[100.0]);return "Owner sandbox restock. No purchase or external utility connection.";}
    if(cmd=="Service"){put(29,[0.0]);return "Equipment serviced for roleplay.";}
    if(cmd=="Send residue")
    {if(fv(40)<10.0)return "Need 10 kg harvested residue.";if(!startTransfer("BROWNS",10))return "Set nearby compost destination or finish pending load.";put(40,[fv(40)-10.0]);return "10 kg dry residue reserved for compost.";}
    if(cmd=="Storage")
    {
        page="storage";string result="Choose a crop to USE 1 kg. Local produce kg: ";integer j;for(j=0;j<6;++j)result+=llList2String(CROPS,j)+" "+(string)fv(34+j)+"; ";return result;
    }
    return "";
}
integer credit(string kind,integer qty)
{
    integer idx=llListFindList(["SEED","WATER","FERTILIZER","COMPOST","DIESEL"],[kind]);
    if(idx>=0)idx+=24;else if(kind=="ENERGY")idx=32;else return FALSE;
    if(fv(idx)+qty>1000000.0)return FALSE;
    if(idx==24)put(idx,[iv(idx)+qty]);else put(idx,[fv(idx)+qty]);return TRUE;
}
string visual(){return llList2Json(JSON_OBJECT,["kind",KIND,"stage",stage(),"crop",iv(8),"fault",fault]);}
extraBoot(){llListen(WORK_NET,"",NULL_KEY,"");}
integer extraListen(integer c,key who,string msg){if(c==WORK_NET){fieldWork(who,msg);return TRUE;}return FALSE;}
service(){sendTransfer();integer watts=0;if(iv(30) && iv(33))watts=2000;reportDemand(watts);}
integer SCHEMA=2;
list migrate(list v)
{
    if(llList2Integer(v,0)==1 && llGetListLength(v)>=48 && (llGetListLength(v)-48)%4==0)
    {v=llList2List(v,0,42)+["",0,100.0,0,20.0,0,0]+llList2List(v,43,-1);v=llListReplaceList(v,[2],0,0);}
    return v;
}
integer textPage(string p){return FALSE;}
string textPrompt(){return "";}
extraLink(integer sender,integer number,string text,key id){powerLink(sender,number,text);}
// @include common.lslinc
