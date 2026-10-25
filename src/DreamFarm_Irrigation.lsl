// Finite pump/tank. WATER deliveries refill a field tank; enable field irrigation.
// Hose geometry is supplied by the builder; distance/head is modeled here.
string DATA="dreamfarm:irrigation:v1";string KIND="IRRIGATION";
integer SCHEMA=1;integer OUT=18;integer BASE=23;integer pumpAt;
// 8 water;9 energy;10 pump enabled;11 valve;12 pressure;13 leak fraction;
// 14 wear;15 parts;16 dispatched litres;17 spilled litres;18..22 outbox.
// @include power.lslinc
fresh(){S=header()+[1000.0,25.0,0,1,0.0,0.0,0.0,5.0,0.0,0.0]+outbox();}
list migrate(list v){return v;}
integer validSpecific(list v)
{
    integer i;for(i=8;i<18;++i)if(!numeric(v,i,0.0,1000000.0))return FALSE;
    return whole(v,10,0,1) && whole(v,11,0,1) && numeric(v,12,0.0,100.0) && numeric(v,13,0.0,0.5) && numeric(v,14,0.0,100.0);
}
tick(float dt){} // Actual delivery throughput uses real seconds, not crop speed.
float pressure()
{
    list d=llGetObjectDetails((key)sv(OUT),[OBJECT_POS]);if(llGetListLength(d)!=1)return 0.0;
    vector delta=llList2Vector(d,0)-llGetPos();
    return clamp(50.0-4.0*llVecMag(delta)-2.0*clamp(delta.z,0.0,100.0),0.0,100.0);
}
string summary(){return "Water "+(string)fv(8)+" L | Energy "+(string)fv(9)+" kWh\nPump "+(string)iv(10)+" | Valve "+(string)iv(11)+" | Pressure "+(string)fv(12)+"\nWear "+(string)fv(14)+"% | Leakage "+(string)(fv(13)*100.0)+"%\nDispatched "+(string)fv(16)+" L | Pending "+(string)iv(OUT+2);}
list buttons(string p)
{if(p=="settings")return ["Destination","Pause","Resume","Back","Close"];return ["Pump","Valve","Leak test","Repair","Sandbox refill","Settings","Close"];}
string action(string c)
{
    if(c=="Pump"){put(10,[!iv(10)]);return "Pump toggled.";}
    if(c=="Valve"){put(11,[!iv(11)]);return "Valve toggled.";}
    if(c=="Leak test"){put(13,[0.2]);return "Training fault: hose leak set to 20%. Repair consumes a part.";}
    if(c=="Repair")
    {if(iv(10))return "Stop the pump first.";if(fv(15)<1.0)return "Need one parts unit.";put(15,[fv(15)-1.0]);put(13,[0.0]);put(14,[0.0]);return "Hose and pump repaired.";}
    if(c=="Sandbox refill"){put(8,[1000.0]);put(9,[25.0]);return "SANDBOX tank and battery refilled; no purchase.";}
    return "";
}
integer credit(string kind,integer qty)
{
    integer slot=-1;if(kind=="WATER")slot=8;if(kind=="ENERGY" && !USE_DPC)slot=9;if(kind=="PARTS")slot=15;
    if(slot<0 || fv(slot)+qty>1000000.0)return FALSE;put(slot,[fv(slot)+qty]);return TRUE;
}
service()
{
    sendTransfer();integer watts=0;if(iv(10) && iv(11))watts=500;reportDemand(watts);
    if(fault || iv(4) || !iv(10) || !iv(11) || iv(OUT+2)>0 || fv(14)>=95.0 || llGetUnixTime()-pumpAt<15)return;
    pumpAt=llGetUnixTime();float p=pressure();if(p<10.0)return;
    if((USE_DPC && !gridLive()) || (!USE_DPC && fv(9)<0.005))return;
    float drawn=20.0/(1.0-fv(13));if(fv(8)<drawn || fv(16)>999980.0)return;
    list before=S;if(!startTransfer("WATER",20))return;
    put(8,[fv(8)-drawn]);if(!USE_DPC)put(9,[fv(9)-0.005]);put(12,[p]);put(14,[fv(14)+0.01]);
    put(16,[fv(16)+20.0]);put(17,[clamp(fv(17)+drawn-20.0,0.0,1000000.0)]);
    if(save(before))sendTransfer();
}
string visual(){return llList2Json(JSON_OBJECT,["kind",KIND,"pump",iv(10),"pressure",fv(12),"fault",fault]);}
extraBoot(){}
integer extraListen(integer c,key who,string msg){return FALSE;}
extraLink(integer sender,integer number,string text,key id){powerLink(sender,number,text);}
integer textPage(string p){return FALSE;}
string textPrompt(){return "";}
transferAck(string kind,integer qty){}
// @include common.lslinc
