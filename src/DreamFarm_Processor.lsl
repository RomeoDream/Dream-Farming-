string DATA="dreamfarm:processor:v1";string KIND="PROCESSOR";
integer SCHEMA=1;integer OUT=20;integer BASE=25;
// 8 bag;9 recipe;10 running;11 progress days;12 output reservation;
// 13 wear;14 capacity;15 selected material;16 accounted process loss;
// 17 batches;18 material page;19 sandbox restocks;20..24 outbox.
list RECIPES=["Feed mill","Wheat dryer","Corn dryer","Flour mill","Dairy","Baler","Silage clamp","Digester","Packhouse","Slurry mixer"];
// @include catalog.lslinc
// @include power.lslinc
list ingredients()
{
    integer n=iv(9);
    if(n==0)return ["WHEAT",6.0,"SOYBEAN",2.0,"HAY",2.0];
    if(n==1)return ["WET_WHEAT",10.0];if(n==2)return ["WET_CORN",10.0];
    if(n==3)return ["WHEAT",10.0];if(n==4)return ["MILK",10.0];
    if(n==5 || n==6)return ["GRASS",10.0];if(n==7)return ["SLURRY",10.0];
    if(n==8)return ["POTATO",10.0];return ["MANURE",5.0,"WATER",5.0];
}
string output(){return llList2String(["FEED","WHEAT","CORN","FLOUR","CHEESE","HAY","SILAGE","DIGESTATE","PACKED_PRODUCE","SLURRY"],iv(9));}
float outputQty(){return llList2Float([10.0,8.0,8.0,8.0,1.0,6.0,8.0,8.0,9.0,8.0],iv(9));}
float gasQty(){if(iv(9)==7)return 1.0;return 0.0;}
float duration(){return llList2Float([0.25,1.0,1.0,0.25,1.0,0.5,7.0,3.0,0.25,0.1],iv(9));}
fresh(){S=header()+[emptyBag(),0,0,0.0,0.0,0.0,1000.0,0,0.0,0,0,0]+outbox();}
list migrate(list v){return v;}
integer validSpecific(list v)
{
    return validBag(llList2String(v,8)) && whole(v,9,0,9) && whole(v,10,0,1) && numeric(v,11,0.0,7.0) && numeric(v,12,0.0,10.0) && numeric(v,13,0.0,100.0) && numeric(v,14,1.0,1000000.0) && whole(v,15,0,30) && numeric(v,16,0.0,1000000.0) && whole(v,17,0,1000000) && whole(v,18,0,3) && whole(v,19,0,1000000);
}
tick(float dt)
{
    if(!iv(10) || fv(13)>=95.0)return;
    float work=low(dt,clamp(duration()-fv(11),0.0,7.0));
    // Silage ferments passively; other buildings need metered local energy.
    if(iv(9)!=6){if(USE_DPC){if(!gridLive())work=0.0;}else work=low(work,stock("ENERGY")/4.0);}
    if(iv(9)==1 || iv(9)==2)work=low(work,stock("DIESEL")/2.0);
    if(work<=0.0)return;
    if(iv(9)!=6 && !USE_DPC)alter("ENERGY",-work*4.0);
    if(iv(9)==1 || iv(9)==2)alter("DIESEL",-work*2.0);
    put(11,[fv(11)+work]);put(13,[clamp(fv(13)+work,0.0,100.0)]);
    if(fv(11)+0.00001>=duration())
    {
        if(totalStock()+iv(OUT+2)+fv(12)>fv(14) || iv(17)>=1000000)return;
        alter(output(),outputQty());if(gasQty()>0.0)alter("BIOGAS",gasQty());
        put(16,[clamp(fv(16)+10.0-fv(12),0.0,1000000.0)]);
        put(10,[0]);put(12,[0.0]);put(17,[iv(17)+1]);
    }
}
string summary()
{return llList2String(RECIPES,iv(9))+"\nRunning "+(string)iv(10)+" | Progress "+(string)fv(11)+" / "+(string)duration()+" days\nWear "+(string)((integer)fv(13))+"% | Energy "+(string)stock("ENERGY")+"\nReserved output "+(string)fv(12)+" | Stock "+(string)((integer)totalStock())+"\nBatches "+(string)iv(17);}
list buttons(string p)
{
    if(p=="settings")return ["Destination","Pause","Resume","Normal","Demo x60","Back","Close"];
    if(p=="recipe")return RECIPES+["Back","Close"];
    if(p=="material")return materialButtons(iv(18));
    return ["Recipe","Run batch","Select material","Send 10","Send 1","Inventory","Service","Generate power","Sandbox utilities","Settings","Close"];
}
string action(string cmd)
{
    if(cmd=="Recipe"){page="recipe";return "";}
    if(page=="recipe")
    {integer n=llListFindList(RECIPES,[cmd]);if(n>=0){if(iv(10))return "Finish the reserved batch before changing recipe.";put(9,[n]);put(11,[0.0]);page="main";return "Recipe selected.";}}
    if(cmd=="Select material"){page="material";put(18,[0]);return "";}
    if(page=="material")
    {if(cmd=="Next"){put(18,[(iv(18)+1)%4]);return "";}integer n=llListFindList(LABELS,[cmd]);if(n>=0){put(15,[n]);page="main";return "";}}
    if(cmd=="Inventory")return bagReport();
    if(cmd=="Run batch")
    {
        if(iv(10))return "A batch is already reserved.";
        if(fv(13)>=95.0)return "Service the machinery first.";
        list recipe=ingredients();integer i;
        for(i=0;i<llGetListLength(recipe);i+=2)if(stock(llList2String(recipe,i))<llList2Float(recipe,i+1))return "Missing recipe ingredients: "+llList2CSV(recipe);
        if(totalStock()-10.0+iv(OUT+2)+outputQty()+gasQty()>fv(14))return "No output capacity.";
        for(i=0;i<llGetListLength(recipe);i+=2)alter(llList2String(recipe,i),-llList2Float(recipe,i+1));
        put(10,[1]);put(11,[0.0]);put(12,[outputQty()+gasQty()]);return "Inputs consumed and output space reserved in one save.";
    }
    if(cmd=="Send 10" || cmd=="Send 1")
    {integer q=10;if(cmd=="Send 1")q=1;string k=llList2String(MATERIALS,iv(15));if(stock(k)<q)return "Not enough selected material.";if(!startTransfer(k,q))return "Set destination or finish pending load.";alter(k,-q);return "Output reserved for delivery.";}
    if(cmd=="Service")
    {if(stock("PARTS")<1.0)return "Deliver one parts unit.";alter("PARTS",-1.0);put(13,[0.0]);return "Parts consumed; machinery serviced.";}
    if(cmd=="Generate power")
    {
        if(USE_DPC)return "This local generator does not feed the DPC grid.";
        if(stock("BIOGAS")<1.0 || fv(13)>=95.0 || totalStock()+iv(OUT+2)+fv(12)+2.0>fv(14))return "Need one biogas unit, maintained equipment and two free storage units.";
        alter("BIOGAS",-1.0);alter("ENERGY",3.0);put(13,[clamp(fv(13)+0.1,0.0,100.0)]);return "One RP biogas unit converted into three local kWh; no DPC grid credit.";
    }
    if(cmd=="Sandbox utilities")
    {if(totalStock()+fv(12)+iv(OUT+2)+45.0>fv(14) || iv(19)>=1000000)return "Capacity reached.";alter("ENERGY",20.0);alter("DIESEL",20.0);alter("PARTS",5.0);put(19,[iv(19)+1]);return "SANDBOX utilities restocked, no external charge.";}
    return "";
}
integer credit(string kind,integer qty)
{if(llListFindList(MATERIALS,[kind])<0 || totalStock()+iv(OUT+2)+fv(12)+qty>fv(14))return FALSE;alter(kind,qty);return TRUE;}
string visual(){return llList2Json(JSON_OBJECT,["kind",KIND,"running",iv(10),"progress",fv(11),"wear",fv(13),"fault",fault]);}
extraBoot(){}
integer extraListen(integer c,key who,string msg){return FALSE;}
extraLink(integer sender,integer number,string text,key id){powerLink(sender,number,text);}
integer textPage(string p){return FALSE;}
string textPrompt(){return "";}
service(){sendTransfer();integer watts=0;if(iv(10) && iv(9)!=6)watts=4000;reportDemand(watts);}
// @include common.lslinc
