// Dream Farming Equine Stable — experimental v0.2
// Persistent local care inventory and stall assignments. No external transfers yet.
// Linkset data persists across script resets; duplicate objects duplicate their inventory.
integer CHANNEL=-918247;
integer listenHandle;
integer stalls=4;
integer hay=0;
integer water=0;
integer bedding=0;
integer manure=0;
integer MAX_STOCK=10000;
integer pendingAssignment=FALSE;
integer lastCare=0;
integer careEnabled=FALSE;
integer careAccountingMode=0; // 0=display-only stable supplies; Herd controls animal welfare.
integer collectedManure=0;
integer stableManureEnabled=FALSE; // Off by default: Herd already produces manure.
key herdRoot=NULL_KEY;
integer herdChannel=-918248;
integer pendingHerd=FALSE;
integer lastHerdCheck=0;
string pendingAnimal="";
string pendingNonce="";
integer pendingUntil=0;
list assigned=[]; // animal UUID strings, manually registered by owner
string PREFIX="dreamfarm:stable:v2:";
integer clampInt(integer v,integer lo,integer hi){if(v<lo)return lo;if(v>hi)return hi;return v;}
integer validUUID(string value){return (key)value!=NULL_KEY && llStringLength(value)==36;}
integer validHerdRoot(key target){
 if(target==NULL_KEY || target==llGetKey())return FALSE;
 list details=llGetObjectDetails(target,[OBJECT_OWNER,OBJECT_POS]);
 if(llGetListLength(details)!=2)return FALSE;
 if(llList2Key(details,0)!=llGetOwner())return FALSE;
 return llVecDist(llGetPos(),llList2Vector(details,1))<=96.0;
}
save(){
 llLinksetDataWrite(PREFIX+"stalls",(string)stalls);
 llLinksetDataWrite(PREFIX+"hay",(string)hay);
 llLinksetDataWrite(PREFIX+"water",(string)water);
 llLinksetDataWrite(PREFIX+"bedding",(string)bedding);
 llLinksetDataWrite(PREFIX+"manure",(string)manure);
 llLinksetDataWrite(PREFIX+"assigned",llList2Json(JSON_ARRAY,assigned));
 llLinksetDataWrite(PREFIX+"careEnabled",(string)careEnabled);
 llLinksetDataWrite(PREFIX+"careAccountingMode",(string)careAccountingMode);
 llLinksetDataWrite(PREFIX+"lastCare",(string)lastCare);
 llLinksetDataWrite(PREFIX+"collectedManure",(string)collectedManure);
 llLinksetDataWrite(PREFIX+"stableManureEnabled",(string)stableManureEnabled);
 llLinksetDataWrite(PREFIX+"herdRoot",(string)herdRoot);
}
load(){
 string value=llLinksetDataRead(PREFIX+"stalls");
 if(value==""){save();return;}
 stalls=clampInt((integer)value,1,8);
 hay=clampInt((integer)llLinksetDataRead(PREFIX+"hay"),0,MAX_STOCK);
 water=clampInt((integer)llLinksetDataRead(PREFIX+"water"),0,MAX_STOCK);
 bedding=clampInt((integer)llLinksetDataRead(PREFIX+"bedding"),0,MAX_STOCK);
 manure=clampInt((integer)llLinksetDataRead(PREFIX+"manure"),0,MAX_STOCK);
 careEnabled=(integer)llLinksetDataRead(PREFIX+"careEnabled");
 careAccountingMode=0; // safety lock: never double-charge feed before Herd transfer protocol is ready.
 lastCare=(integer)llLinksetDataRead(PREFIX+"lastCare");
 collectedManure=clampInt((integer)llLinksetDataRead(PREFIX+"collectedManure"),0,MAX_STOCK);
 stableManureEnabled=(integer)llLinksetDataRead(PREFIX+"stableManureEnabled");
 herdRoot=(key)llLinksetDataRead(PREFIX+"herdRoot");
 string raw=llLinksetDataRead(PREFIX+"assigned");
 if(llJsonValueType(raw,[])==JSON_ARRAY)assigned=llJson2List(raw);
 else assigned=[];
 if(llGetListLength(assigned)>stalls)assigned=llList2List(assigned,0,stalls-1);
}
report(key who){
 llRegionSayTo(who,0,"Dream Stable | Stalls "+(string)llGetListLength(assigned)+"/"+(string)stalls+" | Hay "+(string)hay+" | Water "+(string)water+" | Bedding "+(string)bedding+" | Manure "+(string)manure+" | Collected "+(string)collectedManure+" | Herd "+(string)herdRoot+" | Manure source "+(string)stableManureEnabled+" | Assignments "+llList2CSV(assigned));
}
menu(key who){
 llDialog(who,"Dream Stable (owner-operated experimental care)",["Status","Add hay","Add water","Add bedding","Muck out","Assign UUID","Set Herd","Release last","Stalls +1","Care on","Care off","Close"],CHANNEL);
}
default {
 state_entry(){
  load();
  llSetTimerEvent(60.0);
  listenHandle=llListen(CHANNEL,"",llGetOwner(),"");
  llListen(herdChannel,"",NULL_KEY,"");
  llSetText("Dream Stable | Equine care prototype",<1.0,0.5,0.8>,1.0);
 }
 on_rez(integer start){llResetScript();}
 changed(integer change){if(change & CHANGED_OWNER)llResetScript();}
 touch_start(integer count){key who=llDetectedKey(0);if(who==llGetOwner())menu(who);}
 listen(integer channel,string name,key id,string message){
  if(channel==herdChannel){
   if(id!=herdRoot || llGetOwnerKey(id)!=llGetOwner() || llGetUnixTime()>pendingUntil)return;
   if(llJsonGetValue(message,["type"])!="EQUINE_RESULT" || llJsonGetValue(message,["nonce"])!=pendingNonce || llJsonGetValue(message,["animal"])!=pendingAnimal)return;
   if(llJsonGetValue(message,["valid"])=="1" && llListFindList(assigned,[pendingAnimal])<0 && llGetListLength(assigned)<stalls){assigned += [pendingAnimal];save();llOwnerSay("Verified horse/donkey assigned to stable.");}
   else llOwnerSay("Herd rejected animal or stable is full.");
   pendingAnimal="";pendingNonce="";pendingUntil=0;return;
  }
  if(id!=llGetOwner())return;
  if(message=="Status"){if(herdRoot!=NULL_KEY && !validHerdRoot(herdRoot))llOwnerSay("Warning: saved Herd object is no longer nearby or same-owner.");report(id);menu(id);return;}
  if(message=="Set Herd"){pendingHerd=TRUE;llTextBox(id,"Paste the Herd root object UUID. Must belong to the same owner and region.",CHANNEL);return;}
  if(pendingHerd){pendingHerd=FALSE;if(validUUID(message) && validHerdRoot((key)message)){herdRoot=(key)message;save();llOwnerSay("Same-owner, nearby object saved. Herd identity handshake is still pending.");}else llOwnerSay("Herd target must be an existing same-owner object within 96 m.");menu(id);return;}
  if(message=="Assign UUID"){pendingAssignment=TRUE;llTextBox(id,"Paste an existing Herd animal UUID. This is a local assignment, not yet verified against the Herd controller.",CHANNEL);return;}
  if(pendingAssignment && !validUUID(message)){pendingAssignment=FALSE;llOwnerSay("Invalid animal UUID; no assignment saved.");menu(id);return;}
  if(pendingAssignment && validUUID(message)){
   pendingAssignment=FALSE;
   if(llListFindList(assigned,[message])>=0)llOwnerSay("Animal already assigned.");
   else if(llGetListLength(assigned)>=stalls)llOwnerSay("Stable full.");
   else if(!validHerdRoot(herdRoot))llOwnerSay("Set a valid same-owner Herd first.");
   else {pendingAnimal=message;pendingNonce=(string)llGenerateKey();pendingUntil=llGetUnixTime()+20;llRegionSayTo(herdRoot,herdChannel,llList2Json(JSON_OBJECT,["type","EQUINE_CHECK","animal",pendingAnimal,"nonce",pendingNonce]));llOwnerSay("Checking animal with Herd controller…");}
   menu(id);return;
  }
  if(message=="Care on"){careEnabled=TRUE;lastCare=llGetUnixTime();}
  else if(message=="Care off"){careEnabled=FALSE;}
  else if(message=="Add hay")hay=clampInt(hay+25,0,MAX_STOCK);
  else if(message=="Add water")water=clampInt(water+50,0,MAX_STOCK);
  else if(message=="Add bedding")bedding=clampInt(bedding+20,0,MAX_STOCK);
  else if(message=="Muck out"){integer space=MAX_STOCK-collectedManure;integer moved=clampInt(manure,0,space);collectedManure+=moved;manure-=moved;llOwnerSay("Muck-out collected "+(string)moved+" manure units. Stored locally for future compost delivery; no external transfer claimed.");}
  else if(message=="Release last"){
   if(llGetListLength(assigned)>0)assigned=llDeleteSubList(assigned,-1,-1);
  }
  else if(message=="Stalls +1")stalls=clampInt(stalls+1,1,8);
  else if(message=="Stalls -1"){
   if(stalls>llGetListLength(assigned))stalls=clampInt(stalls-1,1,8);
   else llOwnerSay("Release an assigned animal before reducing stall capacity.");
  }
  else if(message=="Close")return;
  else {pendingAssignment=FALSE;llOwnerSay("Invalid command or UUID.");menu(id);return;}
  save();report(id);menu(id);
 }
 timer(){
  if(pendingAnimal!="" && llGetUnixTime()>pendingUntil){pendingAnimal="";pendingNonce="";llOwnerSay("Herd verification timed out; no stall assignment made.");}
  if(!careEnabled)return;
  integer now=llGetUnixTime();
  if(lastCare<=0){lastCare=now;save();return;}
  // Bound catch-up to four hourly steps after resets or long region downtime.
  integer steps=(now-lastCare)/3600;
  if(steps<=0)return;
  if(steps>4)steps=4;
  integer n=llGetListLength(assigned);
  if(n==0){lastCare=now;save();return;}
  integer i;
  for(i=0;i<steps;++i){
   // Local stable-roleplay units only. Herd controller remains authoritative for animal welfare.
   integer hayNeeded=n*2;
   integer waterNeeded=n*3;
   if(hay<hayNeeded || water<waterNeeded){careEnabled=FALSE;llOwnerSay("Stable care paused: insufficient hay or water.");break;}
   // Do not debit local stock until a Herd acknowledgment/transfer protocol exists.
   if(careAccountingMode) { hay-=hayNeeded;water-=waterNeeded; }
   if(careAccountingMode && bedding>=n)bedding-=n;
   if(stableManureEnabled)manure=clampInt(manure+n,0,MAX_STOCK);
  }
  lastCare=now;
  save();
 }
}
