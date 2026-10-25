// Dream Garden 0.3.0: advanced plant/soil controller. One per separate root prim.
// Choose SPECIES before first use; use a fresh object when changing species.
string SPECIES = "Rose";
string DATA = "dreamgarden:botany:v1";
integer NET = -163847020;
integer CLIMATE = -163847021;
integer VIEW = 47020;
list NAMES = ["Lettuce","Carrot","Tomato","Strawberry","Corn","Pumpkin","Rose","Sunflower","Apple","Tree","Grass"];
// RP hours, deliberately compressed from real plant lifetimes. See REALISM.md.
list GERMINATE = [4.0,8.0,6.0,8.0,8.0,8.0,12.0,8.0,24.0,12.0,2.0];
list VEGETATE = [12.0,24.0,36.0,36.0,48.0,48.0,48.0,48.0,168.0,96.0,6.0];
list BLOOM = [12.0,12.0,12.0,12.0,12.0,12.0,24.0,24.0,24.0,12.0,6.0];
list FILL = [12.0,12.0,24.0,18.0,24.0,24.0,24.0,24.0,48.0,24.0,6.0];
list YIELD = [3,4,6,6,4,2,4,12,12,5,2];
list SEEDS = [12,12,8,4,8,8,6,20,6,4,8];
list ROOT_SPACE = [5.0,10.0,30.0,10.0,40.0,60.0,40.0,20.0,150.0,200.0,5.0];
// Fixed state, followed by six four-field tool receipts:
// 0 version,1 owner,2 species,3 phase (-1 empty,0 seed,1 growing,2 bloom,3 filling,4 ripe,6 dead),
// 4 phase hours,5 water,6 fertility,7 pH,8 health,9 weeds,10 disease/pest pressure,
// 11 litter,12 seeds,13 produce,14 cuttings,15 last UTC,16 ecological clock seconds,
// 17 group,18 paused,19 speed,20 pot litres (0=ground),21 drainage,22 exposure,
// 23 pollination,24 genetic variety,25 age hours,26 harvest cycles,27 seed mode,
// 28 last tool UTC,29 winter chill hours,30 leaf bags,31 logs,32 cut flowers,
// 33 prepared soil,34 chops left,35 last irrigation nonce,36 rootstocks,
// 37 stored cutting/scion genotype,38 darkness stress hours. Receipts start at 39.
list S;
integer species;
integer fault;
integer h;
integer ch;
integer until;
key visitor;
string page;
list buttons;
string envNonce;
integer envIssued;
integer envValidUntil;
integer envReceived;
list indoor; // temperature, humidity, light; rain is excluded indoors
float climateDistance;
key selectedGreenhouse;

integer iv(integer i) { return llList2Integer(S,i); }
float fv(integer i) { return llList2Float(S,i); }
put(integer i,list value) { S=llListReplaceList(S,value,i,i); }
float clamp(float x,float lo,float hi) { if(x<lo)return lo; if(x>hi)return hi; return x; }
integer uuid(string value) { key k=(key)value; if(k)return TRUE; return FALSE; }
integer perennial() { return species==3 || species==6 || species==8 || species==9 || species==10; }
integer season() { return (integer)(fv(16)/604800.0)%4; }
string seasonName() { return llList2String(["Spring","Summer","Autumn","Winter"],season()); }
integer dormant() { return perennial() && season()==3; }
float phaseHours(integer p)
{
    if(p==0)return llList2Float(GERMINATE,species);
    if(p==1)return llList2Float(VEGETATE,species);
    if(p==2)return llList2Float(BLOOM,species);
    return llList2Float(FILL,species);
}
list weather(float clock)
{
    integer s=(integer)(clock/604800.0)%4;
    float hour=(float)((integer)clock%86400)/3600.0;
    integer pattern=((integer)("0x"+llGetSubString(llMD5String((string)((integer)clock/21600),73),0,6)))%100;
    float rain=0.0; if(pattern<25)rain=1.0; if(pattern<7)rain=2.0;
    float temp=llList2Float([16.0,27.0,12.0,1.0],s)+6.0*llSin(TWO_PI*(hour-8.0)/24.0);
    float light=0.0; if(hour>=6.0 && hour<20.0)light=1.0;
    if(rain>0.0)light*=0.45;
    return [temp,50.0+rain*20.0,light,rain];
}
integer near(key id,float distance)
{
    list d=llGetObjectDetails(id,[OBJECT_POS]);
    if(llGetListLength(d)!=1)return FALSE;
    return llVecDist(llList2Vector(d,0),llGetPos())<=distance;
}
integer allowed(key actor)
{
    if(llGetAgentSize(actor)==ZERO_VECTOR || !near(actor,8.0))return FALSE;
    if(actor==llGetOwner())return TRUE;
    key group=llList2Key(llGetObjectDetails(llGetKey(),[OBJECT_GROUP]),0);
    return iv(17) && group!=NULL_KEY && llSameGroup(actor);
}
tell(key who,string text) { llRegionSayTo(who,0,"Dream Garden: "+text); }
string status()
{
    if(fault)return "STORAGE ERROR - actions locked";
    string stage="Empty";
    if(iv(3)>=0)stage=llList2String(["Germinating","Growing","Flowering","Fruit / seeds","Ready","Resting","DEAD"],iv(3));
    if(iv(3)>=0 && iv(3)!=6 && dormant())stage="Winter dormancy";
    string text=SPECIES+" | "+stage+" | "+seasonName();
    text+="\nHealth "+(string)((integer)fv(8))+" | Water "+(string)((integer)fv(5))+" | Feed "+(string)((integer)fv(6));
    text+="\npH "+llGetSubString((string)fv(7),0,3)+" | Weeds "+(string)((integer)fv(9))+" | Disease "+(string)((integer)fv(10));
    text+="\nSeeds "+(string)iv(12)+" | Produce "+(string)iv(13)+" | Cuttings "+(string)iv(14);
    if(iv(18))text+="\nPAUSED";
    if(iv(19)==60)text+=" | DEMO x60";
    if(iv(15)<llGetUnixTime())text+=" | Updating elapsed time";
    return text;
}
render()
{
    vector color=<0.5,0.9,0.4>; if(iv(3)==6 || fault)color=<0.8,0.25,0.15>;
    llSetText("Dream Garden\n"+status(),color,1.0);
    integer stage=iv(3); if(stage>=0 && stage!=6 && dormant())stage=5;
    llMessageLinked(LINK_SET,VIEW,llList2Json(JSON_OBJECT,["phase",stage,"leaves",fv(11),"autumn",season()==2,"health",fv(8),"fault",fault]),NULL_KEY);
}
integer save(list before)
{
    integer result=llLinksetDataWrite(DATA,llList2Json(JSON_ARRAY,S));
    if(result!=LINKSETDATA_OK && result!=LINKSETDATA_NOUPDATE)
    { S=before; fault=TRUE; llOwnerSay("Botany storage failed. Repair space then reset; preserve "+DATA+"."); render(); return FALSE; }
    render(); return TRUE;
}
die()
{
    put(3,[6]); put(8,[0.0]); put(11,[clamp(fv(11)+20.0,0.0,100.0)]);
}
step(float hours)
{
    integer oldSeason=season();
    put(16,[(float)(((integer)fv(16)+llRound(hours*3600.0))%2419200)]);
    list climate=weather(fv(16));
    if(iv(15)>=envReceived && envValidUntil>=iv(15) && llGetListLength(indoor)==3)climate=indoor+[0.0];
    float temp=llList2Float(climate,0);
    float humidity=llList2Float(climate,1);
    float light=llList2Float(climate,2)*fv(22);
    float rain=llList2Float(climate,3);
    float drying=1.0;
    if(fv(20)>0.0)drying=clamp(25.0/fv(20),0.5,4.0);
    if(dormant())drying*=0.35;
    float water=fv(5)+rain*8.0*hours-(0.7+clamp(temp,0.0,50.0)*0.08)*drying*hours;
    if(water>70.0)water-=(water-70.0)*fv(21)*clamp(hours*0.35,0.0,1.0);
    put(5,[clamp(water,0.0,100.0)]);
    put(9,[clamp(fv(9)+hours*0.3*light,0.0,100.0)]);
    if(iv(3)<0 || iv(3)==6)return;
    if(fv(11)>0.0 && !dormant())
    {
        float decay=clamp(hours*0.2,0.0,fv(11));put(11,[fv(11)-decay]);
        put(6,[clamp(fv(6)+decay*0.2,0.0,100.0)]);put(7,[clamp(fv(7)-decay*0.002,0.0,14.0)]);
    }
    put(25,[fv(25)+hours]);
    if(season()==2 && (species==6 || species==8 || species==9))put(11,[clamp(fv(11)+hours*1.5,0.0,100.0)]);
    if(season()==3 && temp>=0.0 && temp<=7.0)put(29,[fv(29)+hours]);
    if(oldSeason==3 && season()!=3 && species==8 && iv(3)>=2 && iv(3)<=4)
    { put(3,[1]); put(4,[phaseHours(1)]); put(23,[0.0]); }
    if(oldSeason==0 && season()==1 && species==8 && iv(3)==2 && fv(23)<50.0)
    {put(3,[1]);put(4,[phaseHours(1)]);put(23,[0.0]);}
    float risk=0.0;
    if(humidity>80.0 && fv(5)>75.0)risk+=hours*0.8;
    if(fv(11)>60.0)risk+=hours*0.3;
    put(10,[clamp(fv(10)+risk-hours*0.03,0.0,100.0)]);
    float damage=0.0;
    if(!dormant() && iv(3)>0)
    {
        float debt=fv(38)+hours;if(light>=0.5)debt=fv(38)-hours*2.0;
        put(38,[clamp(debt,0.0,100.0)]);
        if(fv(38)>24.0)damage+=(fv(38)-24.0)/12.0;
    }
    if(fv(5)<15.0)damage+=(15.0-fv(5))*0.2;
    if(fv(5)>90.0)damage+=(fv(5)-90.0)*0.25;
    if(fv(6)<8.0)damage+=0.6;
    if(fv(6)>95.0)damage+=1.0;
    if(fv(7)<5.5 || fv(7)>7.5)damage+=1.0;
    float frost=2.0; if(perennial())frost=-8.0;
    if(temp<frost)damage+=(frost-temp)*0.8;
    if(temp>35.0)damage+=(temp-35.0)*0.5;
    if(fv(20)>0.0 && fv(20)<llList2Float(ROOT_SPACE,species))damage+=0.6;
    damage+=fv(10)*0.025;
    if(!perennial() && fv(25)>720.0)damage+=5.0;
    put(8,[clamp(fv(8)+(0.4-damage)*hours,0.0,100.0)]);
    if(fv(8)<=0.0){die();return;}
    if(dormant())return;
    if(iv(3)==4)
    {
        put(4,[fv(4)+hours]);
        if(fv(4)>72.0)
        {
            if(perennial() || species==2){put(3,[1]);put(4,[phaseHours(1)]);put(23,[0.0]);}
            else die();
        }
        return;
    }
    float growth=hours*light*clamp(fv(8)/100.0,0.0,1.0)*(1.0-fv(9)/150.0);
    if(iv(3)==0)growth=hours*clamp(fv(8)/100.0,0.0,1.0);
    if(fv(5)<20.0 || fv(5)>90.0 || temp<5.0 || temp>35.0 || fv(6)<5.0)growth=0.0;
    put(6,[clamp(fv(6)-growth*0.12,0.0,100.0)]);
    if(iv(3)==2 && species!=8 && rain==0.0 && temp>10.0 && light>0.0)
        put(23,[clamp(fv(23)+hours*8.0,0.0,100.0)]);
    put(4,[fv(4)+growth]);
    if(fv(4)<phaseHours(iv(3)))return;
    if(iv(3)==1)
    {
        if(species==9 || species==10 || ((species==0 || species==1) && !iv(27)))
        {put(3,[4]);put(4,[0.0]);return;}
        // Established apple trees need winter chilling and a spring bloom window.
        if(species==8 && (season()!=0 || fv(29)<24.0)){put(4,[phaseHours(1)]);return;}
    }
    if(iv(3)==2 && fv(23)<50.0){put(4,[phaseHours(2)]);return;}
    integer next=iv(3)+1; put(3,[next]);put(4,[0.0]);
}
integer advance()
{
    if(fault)return FALSE;
    integer now=llGetUnixTime(); integer remaining=now-iv(15);
    if(remaining<=0)return TRUE;
    list before=S;
    if(iv(18)){put(15,[now]);return save(before);}
    integer count=0;
    while(remaining>0 && count<48)
    {
        integer chunk=3600/iv(19); if(chunk>remaining)chunk=remaining;
        put(15,[iv(15)+chunk]);step((float)(chunk*iv(19))/3600.0);
        remaining-=chunk;++count;
    }
    if(!save(before))return FALSE;
    if(remaining>0){llSetTimerEvent(1.0);return FALSE;}
    llSetTimerEvent(30.0);return TRUE;
}
integer valid(list v)
{
    integer n=llGetListLength(v);
    if(n<39 || n>63 || (n-39)%4!=0)return FALSE;
    if(llList2Integer(v,0)!=1 || llList2String(v,2)!=SPECIES || !uuid(llList2String(v,1)))return FALSE;
    integer i;
    for(i=0;i<39;++i)
    {
        integer t=llGetListEntryType(v,i);
        if(i==1 || i==2 || i==24 || i==35 || i==37){if(t!=TYPE_STRING)return FALSE;}
        else if(t!=TYPE_INTEGER && t!=TYPE_FLOAT)return FALSE;
    }
    integer p=llList2Integer(v,3);if(p< -1 || p>6 || p==5)return FALSE;
    list integers=[0,3,12,13,14,15,17,18,19,26,27,28,30,31,32,33,34,36];
    for(i=0;i<llGetListLength(integers);++i)if(llGetListEntryType(v,llList2Integer(integers,i))!=TYPE_INTEGER)return FALSE;
    list flags=[17,18,27,33];
    for(i=0;i<llGetListLength(flags);++i)
    {integer flag=llList2Integer(v,llList2Integer(flags,i));if(flag<0 || flag>1)return FALSE;}
    if(llList2Integer(v,15)<=0)return FALSE;
    if(llList2Float(v,4)<0.0 || llList2Float(v,25)<0.0 || llList2Float(v,29)<0.0)return FALSE;
    if(llList2Integer(v,26)<0 || llList2Integer(v,26)>1000000 || llList2Integer(v,28)<0)return FALSE;
    if(llList2Integer(v,34)<0 || llList2Integer(v,34)>3)return FALSE;
    if(llList2Integer(v,19)!=1 && llList2Integer(v,19)!=60)return FALSE;
    for(i=5;i<=11;++i)if(llList2Float(v,i)<0.0 || llList2Float(v,i)>100.0)return FALSE;
    if(llList2Float(v,7)>14.0)return FALSE;
    if(p>=0 && !uuid(llList2String(v,24)))return FALSE;
    if(llList2Integer(v,14)>0 && !uuid(llList2String(v,37)))return FALSE;
    for(i=12;i<=14;++i)if(llList2Integer(v,i)<0 || llList2Integer(v,i)>1000000)return FALSE;
    for(i=30;i<=32;++i)if(llList2Integer(v,i)<0 || llList2Integer(v,i)>1000000)return FALSE;
    if(llList2Float(v,20)<0.0 || llList2Float(v,20)>500.0)return FALSE;
    if(llList2Float(v,21)<0.0 || llList2Float(v,21)>1.0)return FALSE;
    if(llList2Float(v,22)<0.0 || llList2Float(v,22)>1.0)return FALSE;
    if(llList2Float(v,16)<0.0 || llList2Float(v,16)>=2419200.0)return FALSE;
    if(llList2Integer(v,36)<0 || llList2Integer(v,36)>1000000)return FALSE;
    if(llList2Float(v,38)<0.0 || llList2Float(v,38)>100.0)return FALSE;
    for(i=39;i<n;i+=4)
    {
        if(!uuid(llList2String(v,i)) || !uuid(llList2String(v,i+1)))return FALSE;
        if(llGetListEntryType(v,i+2)!=TYPE_STRING || llStringLength(llList2String(v,i+2))>200)return FALSE;
        if(llGetListEntryType(v,i+3)!=TYPE_INTEGER || llList2Integer(v,i+3)<=0)return FALSE;
    }
    return TRUE;
}
fresh()
{
    S=[1,(string)llGetOwner(),SPECIES,-1,0.0,60.0,60.0,6.5,100.0,0.0,0.0,0.0,
       5,0,0,llGetUnixTime(),(float)(llGetUnixTime()%2419200),0,0,1,0.0,0.7,1.0,
       0.0,"",0.0,0,0,0,0.0,0,0,0,0,3,"",2,"",0.0];
}
closeMenu(){if(h)llListenRemove(h);h=0;visitor=NULL_KEY;buttons=[];}
show(key who,string which)
{
    closeMenu();visitor=who;page=which;ch=-10000-(integer)llFrand(2000000000.0);
    if(ch==NET || ch==CLIMATE)ch-=3;
    h=llListen(ch,"",who,"");until=llGetUnixTime()+45;
    string text=status();
    buttons=["Plant seed","Plant cutting","Harvest","Care","Supplies","Clear","Close"];
    if(species==8)buttons=llListReplaceList(buttons,["Plant graft"],1,1);
    if(who==llGetOwner())buttons+=["Settings","Environment"];
    if(which=="care")buttons=["Water","Hoe","Manure","Rake","Dig","Treat","Cutting","Pollinate","Let seed","Compost","Back","Close"];
    if(which=="settings")
    {buttons=["Owner only","Share group","Pause","Resume","Ground","Pot 10L","Pot 40L","Planter 200L","Demo x60","Normal speed","Back","Close"];}
    if(which=="environment")buttons=["Full sun","Half shade","Drain open","Drain closed","Back","Close"];
    if(which=="clear"){text="Remove this plant? It is destroyed; saved supplies remain.";buttons=["Confirm clear","Back","Close"];}
    if(which=="supplies")
    {
        text="Seeds "+(string)iv(12)+" | Produce "+(string)iv(13)+" | Cuttings "+(string)iv(14)
          +"\nLeaf bags "+(string)iv(30)+" | Logs "+(string)iv(31)+" | Cut flowers "+(string)iv(32)
          +"\nRootstocks "+(string)iv(36)+"\nProduce use consumes one roleplay unit. Supplies stay in this plot.";
        buttons=["Use produce","Back","Close"];if(who==llGetOwner())buttons+=["Seed supply","Rootstock supply"];
    }
    llDialog(who,text,buttons,ch);
}
string plant(integer cutting)
{
    if(iv(3)!= -1)return "Clear the old plant first.";
    if(!iv(33))return "Prepare soil with Dig or the shovel first.";
    integer index=12;if(cutting)index=14;
    if(iv(index)<1)return "No planting material in this plot.";
    if(cutting && species==8 && iv(36)<1)return "Grafting an apple scion requires a rootstock.";
    if(cutting && !uuid(llList2String(S,37)))return "Stored propagation material has no valid genotype.";
    if(cutting && species==8)put(36,[iv(36)-1]);
    put(index,[iv(index)-1]);put(3,[0]);if(cutting)put(3,[1]);
    put(4,[0.0]);put(8,[100.0]);put(23,[0.0]);put(25,[0.0]);put(27,[0]);put(34,[3]);put(38,[0.0]);
    if(!cutting)put(24,[(string)llGenerateKey()]);
    else put(24,[llList2String(S,37)]);
    return "Planted. Monitor soil, temperature, pests and health.";
}
string harvest()
{
    if(iv(3)!=4 || dormant())return "No harvest is ready.";
    if(iv(26)>=1000000)return "Harvest history counter full; owner maintenance required.";
    if(species==9 && !iv(27))return "Use an axe to fell a timber tree, or Let seed for reproduction.";
    integer amount=(integer)llCeil((float)llList2Integer(YIELD,species)*fv(8)/100.0);
    integer seeds=0;
    if((species!=0 && species!=1 && species!=9 && species!=10) || iv(27))seeds=llList2Integer(SEEDS,species);
    if(iv(27))amount=0;
    integer slot=13;if(species==9)slot=31;
    if(iv(slot)>1000000-amount || iv(12)>1000000-seeds)return "Supply limit reached.";
    put(slot,[iv(slot)+amount]);put(12,[iv(12)+seeds]);put(26,[iv(26)+1]);
    if(perennial() || species==2)
    {put(3,[1]);put(4,[phaseHours(1)*0.5]);put(23,[0.0]);if(species==8)put(29,[0.0]);}
    else die();
    return "Saved "+(string)amount+" produce/log units and "+(string)seeds+" viable seeds. Annuals finish their life cycle.";
}
string care(string action)
{
    if(action=="Water"){put(5,[clamp(fv(5)+25.0,0.0,100.0)]);return "Water applied; repeated watering can waterlog the soil.";}
    if(action=="Hoe"){put(9,[0.0]);return "Weeds removed.";}
    if(action=="Manure"){put(6,[clamp(fv(6)+25.0,0.0,100.0)]);put(7,[clamp(fv(7)+0.1,0.0,14.0)]);return "Aged manure applied. Excess fertility can burn roots.";}
    if(action=="Compost")
    {if(iv(30)<1)return "Rake fallen leaves first.";put(30,[iv(30)-1]);put(6,[clamp(fv(6)+10.0,0.0,100.0)]);return "One saved leaf bag converted to roleplay compost and applied.";}
    if(action=="Rake")
    {
        integer bags=(integer)(fv(11)/10.0);if(iv(30)>1000000-bags)return "Leaf storage full.";
        put(30,[iv(30)+bags]);put(11,[0.0]);return "Leaf litter raked into "+(string)bags+" bags.";
    }
    if(action=="Dig")
    {
        if(iv(3)!= -1 && iv(3)!=6)return "Clear a live plant before digging.";
        put(3,[-1]);put(4,[0.0]);put(33,[1]);put(9,[0.0]);put(21,[0.7]);put(7,[6.5]);return "Soil prepared with balanced pH and drainage. Ready to plant.";
    }
    if(iv(3)<0 || iv(3)==6)return "There is no live plant to tend.";
    if(action=="Treat"){put(10,[clamp(fv(10)-35.0,0.0,100.0)]);return "Pest/disease pressure reduced; fix the growing conditions too.";}
    if(action=="Cutting")
    {
        if((species!=6 && species!=8 && species!=9) || iv(3)<1 || fv(8)<60.0)return "A healthy established woody plant is required.";
        if(iv(14)>=1000000)return "Cutting storage full.";
        if(iv(14)>0 && llList2String(S,37)!=llList2String(S,24))return "Use the stored genotype's cuttings before saving a different genotype.";
        put(37,[llList2String(S,24)]);put(14,[iv(14)+1]);put(8,[fv(8)-8.0]);return "Cutting/scion saved with its parent genotype. Excess cutting weakens the parent.";
    }
    if(action=="Pollinate")
    {
        if(iv(3)!=2)return "Pollinate during flowering.";
        if(species==8)return "Apples need a different flowering apple genotype within 20 m; a clone cannot pollinate itself.";
        put(23,[100.0]);return "Flowers hand-pollinated.";
    }
    if(action=="Let seed")
    {
        if((species!=0 && species!=1 && species!=9) || iv(3)!=4)return "Use this on mature lettuce, carrot or timber trees.";
        put(27,[1]);put(3,[2]);put(4,[0.0]);put(23,[0.0]);return "Plant will flower and set seed; the food harvest is forgone.";
    }
    return "No action.";
}
integer toolAllowed(string kind)
{
    if(iv(18) || fault)return FALSE;
    if(kind=="HOSE" || kind=="SPRINKLER")return fv(5)<70.0;
    if(kind=="HOE")return fv(9)>0.0;
    if(kind=="MANURE")return fv(6)<70.0;
    if(kind=="RAKE")return fv(11)>0.0;
    if(kind=="SHOVEL")return iv(3)== -1 || iv(3)==6;
    if(kind=="AXE")return (species==8 || species==9) && iv(3)>=1 && iv(3)!=6 && fv(8)>0.0 && (iv(3)>=2 || fv(4)>=phaseHours(1));
    if(kind=="MOWER")return species==10 && iv(3)==4 && !dormant();
    if(kind=="SHEARS")return (species==6 || species==7) && iv(3)==2 && !dormant();
    return FALSE;
}
send(key tool,string op,string req,string kind,string text)
{llRegionSayTo(tool,NET,llList2Json(JSON_OBJECT,["v",1,"op",op,"req",req,"tool",kind,"target",(string)tool,"text",text]));}
work(key tool,string req,string kind)
{
    integer i;
    for(i=39;i<llGetListLength(S);i+=4)
        if(llList2String(S,i)==req && llList2Key(S,i+1)==tool){send(tool,"ACK",req,kind,llList2String(S,i+2));return;}
    if(!toolAllowed(kind)){send(tool,"ERR",req,kind,"That tool is not needed or the plant is unavailable.");return;}
    if(llGetUnixTime()-iv(28)<2){send(tool,"ERR",req,kind,"Wait two seconds between actions.");return;}
    list before=S;string result;
    if(kind=="HOSE" || kind=="SPRINKLER")result=care("Water");
    else if(kind=="HOE")result=care("Hoe");
    else if(kind=="MANURE")result=care("Manure");
    else if(kind=="RAKE")result=care("Rake");
    else if(kind=="SHOVEL")result=care("Dig");
    else if(kind=="MOWER")result=harvest();
    else if(kind=="AXE")
    {
        put(34,[iv(34)-1]);result="Chop saved. "+(string)iv(34)+" chops remaining.";
        if(iv(34)<=0)
        {
            if(iv(31)>999995){S=before;send(tool,"ERR",req,kind,"Log storage full.");return;}
            put(31,[iv(31)+5]);die();result="Tree felled. Five logs saved; dig and replant to replace it.";
        }
    }
    else if(kind=="SHEARS")
    {
        if(iv(32)>999997){send(tool,"ERR",req,kind,"Flower storage full.");return;}
        put(32,[iv(32)+3]);
        if(species==6){put(3,[1]);put(4,[phaseHours(1)*0.5]);put(23,[0.0]);}
        else die();
        result="Three cut flowers saved. Cutting prevents this bloom from setting seed.";
    }
    put(28,[llGetUnixTime()]);S+=[req,(string)tool,result,llGetUnixTime()];
    if(llGetListLength(S)>63)S=llDeleteSubList(S,39,42);
    if(save(before))send(tool,"ACK",req,kind,result);else send(tool,"ERR",req,kind,"Storage error; action not saved.");
}
askClimate()
{
    envNonce=(string)llGenerateKey();envIssued=llGetUnixTime();climateDistance=100000.0;
    llRegionSay(CLIMATE,llList2Json(JSON_OBJECT,["v",1,"op","ENV","req",envNonce,"time",envIssued,"water",fv(5),"irrigator",(string)selectedGreenhouse]));
}
boot()
{
    closeMenu();fault=FALSE;indoor=[];envReceived=0;envValidUntil=0;selectedGreenhouse=NULL_KEY;species=llListFindList(NAMES,[SPECIES]);fresh();
    if(species<0){fault=TRUE;llOwnerSay("Unknown SPECIES. Use a name listed in NAMES.");}
    string raw=llLinksetDataRead(DATA);
    if(!fault && raw!="")
    {
        list data=llJson2List(raw);
        if(llJsonValueType(raw,[])!=JSON_ARRAY || !valid(data)){fault=TRUE;llOwnerSay("Botany record/species mismatch; preserved without overwriting.");}
        else if(llList2Key(data,1)==llGetOwner())S=data;
        else save(S);
    }
    else if(!fault)save(S);
    if(!fault)advance();render();llSetTimerEvent(30.0);askClimate();
}
default
{
    state_entry(){llListen(NET,"",NULL_KEY,"");llListen(CLIMATE,"",NULL_KEY,"");boot();}
    on_rez(integer start){boot();}
    changed(integer flags){if(flags & CHANGED_OWNER)boot();}
    touch_start(integer count)
    {key who=llDetectedKey(0);if(!allowed(who) || fault)return;if(advance())show(who,"main");else tell(who,"Updating elapsed time; touch again shortly.");}
    timer()
    {
        if(h && llGetUnixTime()>=until)closeMenu();
        if(advance())
        {
            askClimate();
            if(species==8 && iv(3)==2 && !dormant() && !iv(18))
                llRegionSay(CLIMATE,llList2Json(JSON_OBJECT,["v",1,"op","POLLEN","variety",llList2String(S,24),"time",llGetUnixTime()]));
        }
    }
    listen(integer channel,string name,key source,string message)
    {
        if(channel==ch && source==visitor && llGetUnixTime()<until)
        {
            if(llListFindList(buttons,[message])<0 || !allowed(source) || !advance())return;
            string current=page;closeMenu();if(message=="Close")return;
            if(message=="Back"){show(source,"main");return;}
            if(message=="Care"){show(source,"care");return;}
            if(message=="Supplies"){show(source,"supplies");return;}
            if(message=="Clear"){show(source,"clear");return;}
            if(message=="Settings" && source==llGetOwner()){show(source,"settings");return;}
            if(message=="Environment" && source==llGetOwner()){show(source,"environment");return;}
            list before=S;string result="Settings saved.";
            if(current=="settings" && source==llGetOwner())
            {
                if(message=="Owner only")put(17,[0]);else if(message=="Share group")put(17,[1]);
                else if(message=="Pause")put(18,[1]);else if(message=="Resume")put(18,[0]);
                else if(message=="Demo x60")put(19,[60]);else if(message=="Normal speed")put(19,[1]);
                else
                {
                    float original=fv(20);
                    if(message=="Ground")put(20,[0.0]);else if(message=="Pot 10L")put(20,[10.0]);
                    else if(message=="Pot 40L")put(20,[40.0]);else if(message=="Planter 200L")put(20,[200.0]);
                    if(original!=fv(20) && iv(3)>=0 && iv(3)!=6)
                    {put(8,[clamp(fv(8)-8.0,0.0,100.0)]);result="Repotted. Plant progress preserved; transplant shock costs eight health.";if(fv(8)<=0.0)die();}
                }
            }
            else if(current=="environment" && source==llGetOwner())
            {
                if(message=="Full sun")put(22,[1.0]);else if(message=="Half shade")put(22,[0.5]);
                else if(message=="Drain open")put(21,[0.7]);else if(message=="Drain closed")put(21,[0.0]);
            }
            else if(iv(18))result="Plant is paused.";
            else if(message=="Plant seed")result=plant(FALSE);
            else if(message=="Plant cutting" || message=="Plant graft")result=plant(TRUE);
            else if(message=="Harvest")result=harvest();
            else if(current=="care")result=care(message);
            else if(current=="clear" && message=="Confirm clear"){put(3,[-1]);put(4,[0.0]);result="Plant cleared; supplies retained.";}
            else if(message=="Seed supply" && source==llGetOwner()){if(iv(12)<5)put(12,[5]);result="Owner seed supply restored to at least five.";}
            else if(message=="Rootstock supply" && source==llGetOwner()){if(iv(36)<2)put(36,[2]);result="Owner rootstock supply restored to at least two.";}
            else if(message=="Use produce"){if(iv(13)>0){put(13,[iv(13)-1]);result="One produce unit used for roleplay.";}else result="No produce stored.";}
            if(save(before)){tell(source,result);show(source,"main");}return;
        }
        if(fault || llStringLength(message)>1000 || llJsonValueType(message,[])!=JSON_OBJECT)return;
        if(llJsonGetValue(message,["v"])!="1" || llGetAgentSize(source)!=ZERO_VECTOR)return;
        string op=llJsonGetValue(message,["op"]);
        if(channel==CLIMATE)
        {
            if(source==llGetKey() || llGetOwnerKey(source)!=llGetOwner() || !near(source,30.0))return;
            if(op=="POLLEN" && species==8 && iv(3)==2 && !dormant() && !iv(18))
            {
                integer age=llGetUnixTime()-(integer)llJsonGetValue(message,["time"]);
                string variety=llJsonGetValue(message,["variety"]);
                if(age<0 || age>10 || !uuid(variety) || variety==llList2String(S,24) || !near(source,20.0))return;
                list before=S;put(23,[100.0]);save(before);return;
            }
            if(op=="ENV_REPLY" && llJsonGetValue(message,["req"])==envNonce && llGetUnixTime()-envIssued<=10)
            {
                if(llJsonGetValue(message,["target"])!=(string)llGetKey())return;
                float distance=llVecDist(llList2Vector(llGetObjectDetails(source,[OBJECT_POS]),0),llGetPos());
                if(distance>=climateDistance)return;
                float temperature=(float)llJsonGetValue(message,["temp"]);
                float humidity=(float)llJsonGetValue(message,["humidity"]);
                float light=(float)llJsonGetValue(message,["light"]);
                if(temperature< -50.0 || temperature>80.0 || humidity<0.0 || humidity>100.0 || light<0.0 || light>1.0)return;
                if(!advance())return;
                indoor=[temperature,humidity,light];envReceived=llGetUnixTime();envValidUntil=llGetUnixTime()+90;climateDistance=distance;selectedGreenhouse=source;
                if(llJsonGetValue(message,["irrigation"])=="1" && llList2String(S,35)!=envNonce && !iv(18))
                {list before=S;put(5,[clamp(fv(5)+20.0,0.0,100.0)]);put(35,[envNonce]);save(before);}
            }
            return;
        }
        if(channel!=NET)return;
        key actor=(key)llJsonGetValue(message,["actor"]);string req=llJsonGetValue(message,["req"]);
        string kind=llJsonGetValue(message,["tool"]);
        integer access=allowed(actor);
        if(kind=="SPRINKLER" && actor==llGetOwner())access=TRUE;
        if(!uuid(req) || llGetOwnerKey(source)!=actor || !access || !near(source,8.0))return;
        if(llJsonValueType(message,["time"])!=JSON_NUMBER)return;
        integer age=llGetUnixTime()-(integer)llJsonGetValue(message,["time"]);if(age<0 || age>10)return;
        if(!advance())return;
        if(op=="SCAN" && toolAllowed(kind))send(source,"OFFER",req,kind,SPECIES);
        else if(op=="USE" && llJsonGetValue(message,["target"])==(string)llGetKey())work(source,req,kind);
    }
    link_message(integer sender,integer number,string text,key id)
    {if(number==VIEW+1)render();}
}
