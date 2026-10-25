string DATA="dreamfarm:compost:v1";
string KIND="COMPOST";
integer OUT=24;
integer BASE=29;
// 8 fresh manure kg;9 dry bedding/leaves kg;10 loaded batch kg;11 C:N;
// 12 moisture%;13 oxygen%;14 temperature C;15 active days;16 cure days;
// 17 phase(0 filling,1 active,2 curing);18 mature compost kg;19 water L;
// 20 mixer wear%;21 latest quality%;22 lifetime matured kg;23 supply deliveries;
// 24..28 reliable outbox; receipt table follows.
fresh(){S=header()+[0.0,20.0,0.0,0.0,50.0,100.0,20.0,0.0,0.0,0,0.0,100.0,0.0,0.0,0.0,0]+outbox();}
integer validSpecific(list v)
{
    integer i;for(i=8;i<24;++i)if(!numeric(v,i,0.0,1000000.0))return FALSE;
    for(i=12;i<=13;++i)if(!numeric(v,i,0.0,100.0))return FALSE;
    if(!numeric(v,14,0.0,80.0) || !numeric(v,20,0.0,100.0) || !numeric(v,21,0.0,100.0))return FALSE;
    return whole(v,17,0,2) && whole(v,23,0,1000000);
}
tick(float dt)
{
    if(iv(17)==0)return;
    float moisture=clamp(1.0-llFabs(fv(12)-55.0)/30.0,0.0,1.0);
    float balance=clamp(1.0-llFabs(fv(11)-30.0)/25.0,0.0,1.0);
    float activity=moisture*balance*clamp(fv(13)/50.0,0.0,1.0);
    if(iv(17)==1)
    {
        float target=20.0+42.0*activity;
        put(14,[clamp(fv(14)+(target-fv(14))*low(dt*2.0,1.0),0.0,80.0)]);
        put(13,[clamp(fv(13)-dt*10.0*activity,0.0,100.0)]);
        put(12,[clamp(fv(12)-dt*(0.4+activity),0.0,100.0)]);
        // Game maturity needs productive warm aerobic time, not idle calendar age.
        if(fv(14)>=40.0 && fv(13)>=20.0)put(15,[fv(15)+activity*dt]);
        if(fv(15)>=7.0){put(17,[2]);put(16,[0.0]);}
    }
    else
    {
        put(14,[fv(14)+(20.0-fv(14))*low(dt,1.0)]);
        if(moisture>0.4 && fv(13)>20.0)put(16,[fv(16)+dt]);
        if(fv(16)>=7.0)
        {
            float amount=fv(10)*0.55;
            if(fv(18)+amount>1000000.0 || fv(22)+amount>1000000.0)return;
            put(18,[fv(18)+amount]);put(22,[fv(22)+amount]);put(21,[clamp(balance*100.0,0.0,100.0)]);
            put(10,[0.0]);put(17,[0]);
        }
    }
}
string summary()
{
    return llList2String(["Filling","Active composting","Curing"],iv(17))+"\nFresh manure "+(string)((integer)fv(8))+" kg | Browns "+(string)((integer)fv(9))+" kg"+
    "\nMoisture "+(string)((integer)fv(12))+"% | Air "+(string)((integer)fv(13))+"% | "+(string)((integer)fv(14))+" C"+
    "\nC:N "+(string)((integer)fv(11))+":1 | Active "+(string)fv(15)+" d | Cured "+(string)fv(16)+" d"+
    "\nMature "+(string)((integer)fv(18))+" kg | Quality "+(string)((integer)fv(21))+"%\nPending "+(string)iv(OUT+2)+" kg | Paused "+(string)iv(4);
}
list buttons(string p)
{
    if(p=="settings")return ["Destination","Pause","Resume","Normal","Demo x60","Back","Close"];
    return ["Start batch","Balanced batch","Leaf batch","Turn pile","Water pile","Dry pile","Browns 20","Refill water","Send compost","Service mixer","Settings","Close"];
}
string action(string cmd)
{
    if(cmd=="Start batch" || cmd=="Balanced batch" || cmd=="Leaf batch")
    {
        float brown=5.0;if(cmd=="Balanced batch")brown=10.0;if(cmd=="Leaf batch")brown=20.0;
        if(iv(17)!=0 || fv(8)<10.0 || fv(9)<brown)return "Need an empty pile, 10 kg manure and "+(string)brown+" kg dry browns.";
        // RP material model: manure C=30%, N=2%; dry browns C=45%, N=0.5%.
        float cn=(10.0*0.30+brown*0.45)/(10.0*0.02+brown*0.005);
        put(8,[fv(8)-10.0]);put(9,[fv(9)-brown]);put(10,[10.0+brown]);put(11,[cn]);
        put(12,[55.0]);put(13,[100.0]);put(14,[20.0]);put(15,[0.0]);put(16,[0.0]);put(17,[1]);
        return "Batch started. Turn and control moisture; then allow a separate curing stage.";
    }
    if(cmd=="Turn pile")
    {if(iv(17)==0)return "No active batch.";if(fv(20)>95.0)return "Service the mixer.";put(13,[100.0]);put(20,[fv(20)+5.0]);return "Pile aerated; mixer wear increased.";}
    if(cmd=="Water pile")
    {if(fv(19)<5.0)return "Water tank empty.";put(19,[fv(19)-5.0]);put(12,[clamp(fv(12)+10.0,0.0,100.0)]);return "Added 5 L. Excess water reduces compost activity.";}
    if(cmd=="Dry pile"){put(12,[clamp(fv(12)-10.0,0.0,100.0)]);return "Pile uncovered and drained for roleplay.";}
    if(cmd=="Browns 20" || cmd=="Refill water")
    {
        integer i=9;float qty=20.0;if(cmd=="Refill water"){i=19;qty=100.0;}
        if(fv(i)+qty>1000000.0 || iv(23)>=1000000)return "Supply storage full.";
        put(i,[fv(i)+qty]);put(23,[iv(23)+1]);return "Roleplay supply delivery recorded; no money charged.";
    }
    if(cmd=="Send compost")
    {
        if(fv(18)<2.0)return "Need at least 2 kg mature compost. Fresh manure cannot be exported as compost.";
        if(!startTransfer("COMPOST",2))return "Set a nearby same-owner field or Garden applicator destination; finish pending load.";
        put(18,[fv(18)-2.0]);return "2 kg mature compost reserved for delivery.";
    }
    if(cmd=="Service mixer"){put(20,[0.0]);return "Mixer serviced for roleplay.";}
    return "";
}
integer credit(string kind,integer qty)
{
    integer i=-1;if(kind=="MANURE" || kind=="DIGESTATE")i=8;if(kind=="BROWNS")i=9;
    if(i<0 || fv(i)+(float)qty>1000000.0)return FALSE;
    put(i,[fv(i)+(float)qty]);return TRUE;
}
string visual(){return llList2Json(JSON_OBJECT,["kind",KIND,"phase",iv(17),"temp",fv(14),"stock",fv(18),"fault",fault]);}
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
