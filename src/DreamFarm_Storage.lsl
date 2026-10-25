// Silo, warehouse, cold store or transport trailer; same finite inventory model.
string DATA="dreamfarm:storage:v1";
string KIND="STORAGE";
integer SCHEMA=1;
integer OUT=17;integer BASE=22;
// 8 inventory JSON;9 capacity units;10 cold enabled;11 selected material;
// 12 spoilage;13 inbound units;14 sandbox deliveries;15 export size;16 unit-count page.
// @include catalog.lslinc
// @include power.lslinc
fresh(){S=header()+[emptyBag(),2500.0,0,0,0.0,0.0,0,10,0]+outbox();}
list migrate(list v){return v;}
integer validSpecific(list v)
{
    if(!validBag(llList2String(v,8)) || !numeric(v,9,1.0,1000000.0) || !whole(v,10,0,1) || !whole(v,11,0,30))return FALSE;
    return numeric(v,12,0.0,1000000.0) && numeric(v,13,0.0,1000000.0) && whole(v,14,0,1000000) && whole(v,15,1,1000) && whole(v,16,0,3);
}
tick(float dt)
{
    float factor=1.0;
    if(iv(10) && ((!USE_DPC && stock("ENERGY")>=dt*2.0) || gridLive())){if(!USE_DPC)alter("ENERGY",-dt*2.0);factor=0.15;}
    integer i;for(i=0;i<llGetListLength(MATERIALS);++i)
    {string k=llList2String(MATERIALS,i);float loss=stock(k)*(1.0-llPow(1.0-decay(k)*factor,dt));if(loss>0.0){alter(k,-loss);put(12,[clamp(fv(12)+loss,0.0,1000000.0)]);}}
}
string summary()
{string k=llList2String(MATERIALS,iv(11));return "Used "+(string)((integer)totalStock())+" / "+(string)((integer)fv(9))+" units\nSelected "+llList2String(LABELS,iv(11))+": "+(string)stock(k)+"\nCold storage "+(string)iv(10)+" | Energy "+(string)stock("ENERGY")+"\nSend amount "+(string)iv(15)+" | Reserved "+(string)iv(OUT+2)+"\nSpoiled "+(string)fv(12);}
list buttons(string p)
{
    if(p=="settings")return ["Destination","Pause","Resume","Normal","Demo x60","Back","Close"];
    if(p=="material")return materialButtons(iv(16));
    return ["Select material","Send load","Size 1","Size 10","Size 100","Cold storage","Inventory","Sandbox +100","Settings","Close"];
}
string action(string cmd)
{
    if(cmd=="Select material"){page="material";put(16,[0]);return "";}
    if(page=="material")
    {if(cmd=="Next"){put(16,[(iv(16)+1)%4]);return "";}integer n=llListFindList(LABELS,[cmd]);if(n>=0){put(11,[n]);page="main";return "Material selected.";}}
    if(cmd=="Size 1")put(15,[1]);if(cmd=="Size 10")put(15,[10]);if(cmd=="Size 100")put(15,[100]);
    if(cmd=="Cold storage")put(10,[!iv(10)]);
    if(cmd=="Inventory")return bagReport();
    string k=llList2String(MATERIALS,iv(11));
    if(cmd=="Send load")
    {integer q=iv(15);if(stock(k)<q)return "Not enough material.";if(!startTransfer(k,q))return "Set a nearby same-owner destination and finish pending load.";alter(k,-q);return "Load reserved; await receipt.";}
    if(cmd=="Sandbox +100")
    {if(totalStock()+iv(OUT+2)+100.0>fv(9) || iv(14)>=1000000)return "Capacity reached.";alter(k,100.0);put(14,[iv(14)+1]);return "SANDBOX supply added; no purchase or bank debit.";}
    return "";
}
integer credit(string kind,integer qty)
{
    if(llListFindList(MATERIALS,[kind])<0 || totalStock()+iv(OUT+2)+qty>fv(9) || fv(13)+qty>1000000.0)return FALSE;
    alter(kind,qty);put(13,[fv(13)+qty]);return TRUE;
}
string visual(){return llList2Json(JSON_OBJECT,["kind",KIND,"stock",totalStock(),"capacity",fv(9),"cold",iv(10),"fault",fault]);}
extraBoot(){}
integer extraListen(integer c,key who,string msg){return FALSE;}
extraLink(integer sender,integer number,string text,key id){powerLink(sender,number,text);}
integer textPage(string p){return FALSE;}
string textPrompt(){return "";}
service(){sendTransfer();integer watts=0;if(iv(10))watts=2000;reportDemand(watts);}
// @include common.lslinc
