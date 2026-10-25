// Romeo Dream - finite standing grass, regrowth, resting and controlled grazing.
string DATA="dreamfarm:pasture:v1";string KIND="PASTURE";
integer SCHEMA=1;integer OUT=19;integer BASE=24;integer fedAt;
// 8 supplies/cut grass;9 standing grass;10 sward health;11 soil moisture;
// 12 fertility;13 automatic grazing delivery;14 cumulative growth;
// 15 dispatched grazing;16 lost grass;17 reserved;18 compaction;19..23 outbox.
// @include catalog.lslinc
// @include climate.lslinc
fresh(){S=header()+[emptyBag(),600.0,100.0,60.0,60.0,0,0.0,0.0,0.0,0,0.0]+outbox();alter("WATER",100.0);alter("SEED",2.0);}
list migrate(list v){return v;}
integer validSpecific(list v)
{
    if(!validBag(llList2String(v,8)) || !numeric(v,9,0.0,1000.0) || !whole(v,13,0,1) || !whole(v,17,0,0))return FALSE;
    integer i;for(i=10;i<=12;++i)if(!numeric(v,i,0.0,100.0))return FALSE;
    for(i=14;i<=16;++i)if(!numeric(v,i,0.0,1000000.0))return FALSE;
    return numeric(v,18,0.0,100.0) && totalStock()<=2000.01;
}
tick(float dt)
{
    float temp=farmTemperature(fv(6));float water=fv(11)+farmRain(fv(6))*dt-clamp(2.0+temp*0.12,0.5,8.0)*dt;
    put(11,[clamp(water,0.0,100.0)]);
    float cover=clamp(fv(9)/100.0,0.0,1.0);
    float growth=80.0*dt*cover*(1.0-fv(9)/1000.0)*(fv(10)/100.0)*clamp(fv(11)/35.0,0.0,1.0)*clamp((100.0-fv(11))/15.0,0.0,1.0)*clamp(fv(12)/35.0,0.0,1.0)*clamp(temp/15.0,0.0,1.0)*farmLight(fv(6))*(1.0-fv(18)*0.006);
    growth=low(growth,1000.0-fv(9));put(9,[fv(9)+growth]);put(14,[clamp(fv(14)+growth,0.0,1000000.0)]);put(12,[clamp(fv(12)-growth*0.01,0.0,100.0)]);
    float loss=0.0;if(temp<0.0 || fv(11)<5.0 || fv(11)>95.0)loss=low(fv(9),fv(9)*0.03*dt);
    put(9,[fv(9)-loss]);put(16,[clamp(fv(16)+loss,0.0,1000000.0)]);
    float recovery=1.0;if(iv(13))recovery=0.2;
    put(10,[clamp(fv(10)+dt*(recovery-(1.0-cover)*4.0),0.0,100.0)]);
    float compaction=-0.5;if(iv(13))compaction=0.5;
    put(18,[clamp(fv(18)+compaction*dt,0.0,100.0)]);
    float spoiled=stock("GRASS")*(1.0-llPow(0.92,dt));alter("GRASS",-spoiled);put(16,[clamp(fv(16)+spoiled,0.0,1000000.0)]);
}
string summary()
{return "Standing grass "+(string)fv(9)+" / 1000 | Sward health "+(string)fv(10)+"%\nMoisture "+(string)fv(11)+" | Fertility "+(string)fv(12)+" | Compaction "+(string)fv(18)+"\nGrazing supply "+(string)iv(13)+" | Cut grass "+(string)stock("GRASS")+"\nAuto feed retains 100 standing units; low cutting damages cover.";}
list buttons(string p)
{
    if(p=="settings")return ["Destination","Pause","Resume","Normal","Demo x60","Back","Close"];
    if(p=="lowcut")return ["Confirm low cut","Back","Close"];
    return ["Grazing gate","Mow 50","Low cut","Send cut grass","Water pasture","Apply compost","Reseed","Inventory","Settings","Close"];
}
string action(string cmd)
{
    if(cmd=="Grazing gate"){put(13,[!iv(13)]);return "Grazing supply toggled. Set a nearby Herd destination and enable its Grazing option.";}
    if(cmd=="Low cut"){page="lowcut";return "Low cutting can remove the protective residual. Confirm to cut up to 50 more units.";}
    if(cmd=="Mow 50" || cmd=="Confirm low cut")
    {
        float amount=50.0;if(cmd=="Confirm low cut"){amount=low(50.0,fv(9));page="main";}
        else if(fv(9)<150.0)return "Keep at least 100 standing units for regrowth.";
        if(amount<=0.0 || totalStock()+iv(OUT+2)+amount>2000.0)return "No grass or cut-grass capacity.";
        put(9,[fv(9)-amount]);alter("GRASS",amount);
        if(fv(9)<100.0)put(10,[clamp(fv(10)-5.0,0.0,100.0)]);
        return "Grass cut and retained as finite stock.";
    }
    if(cmd=="Send cut grass")
    {if(stock("GRASS")<20.0)return "Need 20 cut grass units.";if(!startTransfer("GRASS",20))return "Set destination or finish pending delivery.";alter("GRASS",-20.0);return "Cut grass reserved.";}
    if(cmd=="Water pasture")
    {if(stock("WATER")<20.0)return "Need 20 water.";alter("WATER",-20.0);put(11,[clamp(fv(11)+10.0,0.0,100.0)]);return "Finite water applied.";}
    if(cmd=="Apply compost")
    {if(stock("COMPOST")<2.0)return "Need two mature compost units.";alter("COMPOST",-2.0);put(12,[clamp(fv(12)+10.0,0.0,100.0)]);return "Mature compost applied.";}
    if(cmd=="Reseed")
    {
        if(iv(13) || fv(9)>100.0 || stock("SEED")<1.0)return "Close grazing, reduce cover to 100 or less and supply one seed unit.";
        alter("SEED",-1.0);put(9,[fv(9)+25.0]);put(10,[clamp(fv(10)+20.0,0.0,100.0)]);return "Pasture reseeded; seed consumed and 25 seedling-cover units established.";
    }
    if(cmd=="Inventory")return bagReport();return "";
}
integer credit(string kind,integer qty)
{if(llListFindList(["WATER","COMPOST","SEED"],[kind])<0 || totalStock()+iv(OUT+2)+qty>2000.0)return FALSE;alter(kind,qty);return TRUE;}
service()
{
    sendTransfer();
    if(fault || iv(4) || !iv(13) || iv(OUT+2)>0 || fv(9)<120.0 || fv(15)>999980.0 || llGetUnixTime()-fedAt<15)return;
    fedAt=llGetUnixTime();list before=S;if(!startTransfer("GRASS",20))return;
    put(9,[fv(9)-20.0]);put(15,[fv(15)+20.0]);if(save(before))sendTransfer();
}
string visual(){return llList2Json(JSON_OBJECT,["kind",KIND,"grass",fv(9),"health",fv(10),"grazing",iv(13),"fault",fault]);}
extraBoot(){}
integer extraListen(integer c,key who,string msg){return FALSE;}
extraLink(integer sender,integer number,string text,key id){}
integer textPage(string p){return FALSE;}
string textPrompt(){return "";}
transferAck(string kind,integer qty){}
// @include common.lslinc
