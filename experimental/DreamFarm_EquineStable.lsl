// Dream Farming Equine Stable — experimental integration alpha
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
integer menuPage=0;
integer lastCare=0;
integer careEnabled=FALSE;
// Local stable supply quantities are observational until an acknowledged transfer exists.
integer careAccountingMode=0;
integer lastSupplyAudit=0;
integer NET=-163847025;
string transferStream="";
integer transferSeq=0;
integer pendingWater=0; // pending quantity; retained key for migration compatibility
string pendingKind="WATER";
integer lastWaterSend=0;
integer pendingStarted=0;
integer transferAttempts=0;
integer collectedManure=0;
// Stable never creates manure: Herd is authoritative.
integer stableManureEnabled=FALSE;
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
integer transferInRange(){
 if(!validHerdRoot(herdRoot))return FALSE;
 list pos=llGetObjectDetails(herdRoot,[OBJECT_POS]);
 if(llGetListLength(pos)!=1)return FALSE;
 return llVecDist(llGetPos(),llList2Vector(pos,0))<=8.0;
}
save(){
 llLinksetDataWrite(PREFIX+"owner",(string)llGetOwner());
 llLinksetDataWrite(PREFIX+"stalls",(string)stalls);
 llLinksetDataWrite(PREFIX+"hay",(string)hay);
 llLinksetDataWrite(PREFIX+"water",(string)water);
 llLinksetDataWrite(PREFIX+"bedding",(string)bedding);
 llLinksetDataWrite(PREFIX+"manure",(string)manure);
 llLinksetDataWrite(PREFIX+"assigned",llList2Json(JSON_ARRAY,assigned));
 llLinksetDataWrite(PREFIX+"careEnabled",(string)careEnabled);
 llLinksetDataWrite(PREFIX+"careAccountingMode",(string)careAccountingMode);
 llLinksetDataWrite(PREFIX+"lastSupplyAudit",(string)lastSupplyAudit);
 llLinksetDataWrite(PREFIX+"transferStream",transferStream);
 llLinksetDataWrite(PREFIX+"transferSeq",(string)transferSeq);
 llLinksetDataWrite(PREFIX+"pendingWater",(string)pendingWater);
 llLinksetDataWrite(PREFIX+"pendingKind",pendingKind);
 llLinksetDataWrite(PREFIX+"pendingStarted",(string)pendingStarted);
 llLinksetDataWrite(PREFIX+"transferAttempts",(string)transferAttempts);
 llLinksetDataWrite(PREFIX+"lastCare",(string)lastCare);
 llLinksetDataWrite(PREFIX+"collectedManure",(string)collectedManure);
 llLinksetDataWrite(PREFIX+"stableManureEnabled",(string)stableManureEnabled);
 llLinksetDataWrite(PREFIX+"herdRoot",(string)herdRoot);
}
load(){
 string value=llLinksetDataRead(PREFIX+"stalls");
 if(value==""){transferStream=(string)llGenerateKey();save();return;}
 string savedOwner=llLinksetDataRead(PREFIX+"owner");
 if(savedOwner!="" && savedOwner!=(string)llGetOwner()){
  stalls=4;hay=0;water=0;bedding=0;manure=0;collectedManure=0;
  assigned=[];careEnabled=FALSE;herdRoot=NULL_KEY;pendingWater=0;pendingKind="WATER";pendingStarted=0;transferAttempts=0;transferSeq=0;
  transferStream=(string)llGenerateKey();lastCare=0;lastSupplyAudit=0;
  save();llOwnerSay("Ownership changed: previous owner stable records and credentials were cleared.");return;
 }
 stalls=clampInt((integer)value,1,8);
 hay=clampInt((integer)llLinksetDataRead(PREFIX+"hay"),0,MAX_STOCK);
 water=clampInt((integer)llLinksetDataRead(PREFIX+"water"),0,MAX_STOCK);
 bedding=clampInt((integer)llLinksetDataRead(PREFIX+"bedding"),0,MAX_STOCK);
 manure=clampInt((integer)llLinksetDataRead(PREFIX+"manure"),0,MAX_STOCK);
 careEnabled=(integer)llLinksetDataRead(PREFIX+"careEnabled");
 careAccountingMode=0; // safety lock: never double-charge feed before Herd transfer protocol is ready.
 lastSupplyAudit=(integer)llLinksetDataRead(PREFIX+"lastSupplyAudit");
 transferStream=llLinksetDataRead(PREFIX+"transferStream");
 if(transferStream=="")transferStream=(string)llGenerateKey();
 transferSeq=(integer)llLinksetDataRead(PREFIX+"transferSeq");
 pendingWater=clampInt((integer)llLinksetDataRead(PREFIX+"pendingWater"),0,1000);
 pendingKind=llLinksetDataRead(PREFIX+"pendingKind");
 if(pendingKind!="WATER" && pendingKind!="FEED")pendingKind="WATER";
 pendingStarted=(integer)llLinksetDataRead(PREFIX+"pendingStarted");
 transferAttempts=clampInt((integer)llLinksetDataRead(PREFIX+"transferAttempts"),0,1000000);
 lastCare=(integer)llLinksetDataRead(PREFIX+"lastCare");
 collectedManure=clampInt((integer)llLinksetDataRead(PREFIX+"collectedManure"),0,MAX_STOCK);
 stableManureEnabled=(integer)llLinksetDataRead(PREFIX+"stableManureEnabled");
 herdRoot=(key)llLinksetDataRead(PREFIX+"herdRoot");
 string raw=llLinksetDataRead(PREFIX+"assigned");
 if(llJsonValueType(raw,[])==JSON_ARRAY)assigned=llJson2List(raw);
 else assigned=[];
 // Older builds permitted unverified UUIDs; invalidate those assignments once.
 if(llLinksetDataRead(PREFIX+"verifiedAssignments")!="1"){
  assigned=[];
  careEnabled=FALSE;
  llLinksetDataWrite(PREFIX+"verifiedAssignments","1");
  save();
 }
 if(llGetListLength(assigned)>stalls)assigned=llList2List(assigned,0,stalls-1);
}
report(key who){
 llRegionSayTo(who,0,"Dream Stable | Stalls "+(string)llGetListLength(assigned)+"/"+(string)stalls+" | Hay "+(string)hay+" | Water "+(string)water+" | Bedding "+(string)bedding+" | Manure "+(string)manure+" | Collected "+(string)collectedManure+" | Pending water "+(string)pendingWater+" | Herd "+(string)herdRoot+" | Manure source "+(string)stableManureEnabled+" | Assignments "+llList2CSV(assigned));
}
menu(key who){
 if(menuPage==1)llDialog(who,"Stable settings",["Release last","Stalls +1","Stalls -1","Send feed","Back","Close"],CHANNEL);
 else llDialog(who,"Dream Stable (owner-operated experimental care)",["Status","Add hay","Add water","Add bedding","Muck out","Assign UUID","Set Herd","More","Send water","Care on","Care off","Close"],CHANNEL);
}
default {
 state_entry(){
  load();
  llSetTimerEvent(60.0);
  listenHandle=llListen(CHANNEL,"",llGetOwner(),"");
  llListen(herdChannel,"",NULL_KEY,"");
  llListen(NET,"",NULL_KEY,"");
  llSetText("Dream Stable | Equine care prototype",<1.0,0.5,0.8>,1.0);
 }
 on_rez(integer start){llResetScript();}
 changed(integer change){if(change & CHANGED_OWNER)llResetScript();}
 touch_start(integer count){key who=llDetectedKey(0);if(who==llGetOwner())menu(who);}
 listen(integer channel,string name,key id,string message){
  if(channel==NET){
   if(llStringLength(message)>1000 || llJsonValueType(message,[])!=JSON_OBJECT)return;
   if(llJsonValueType(message,["seq"])!=JSON_NUMBER || llJsonValueType(message,["qty"])!=JSON_NUMBER)return;
   if((float)llJsonGetValue(message,["seq"])!=(float)transferSeq || (float)llJsonGetValue(message,["qty"])!=(float)pendingWater)return;
   if(pendingWater<=0 || id!=herdRoot || llGetOwnerKey(id)!=llGetOwner() || !validHerdRoot(herdRoot))return;
   if(llJsonGetValue(message,["v"])!="1" || llJsonGetValue(message,["op"])!="ACK" || llJsonGetValue(message,["target"])!=(string)llGetKey())return;
   if(llJsonGetValue(message,["stream"])!=transferStream || (integer)llJsonGetValue(message,["seq"])!=transferSeq || (integer)llJsonGetValue(message,["qty"])!=pendingWater || llJsonGetValue(message,["kind"])!=pendingKind)return;
   if(pendingKind=="WATER")water-=pendingWater;
   else hay-=pendingWater;
   string delivered=pendingKind;pendingWater=0;pendingKind="WATER";pendingStarted=0;transferAttempts=0;save();llOwnerSay("Herd acknowledged "+delivered+" delivery; stable stock debited once.");return;
  }
  if(channel==herdChannel){
   if(llStringLength(message)>1000 || llJsonValueType(message,[])!=JSON_OBJECT)return;
   if(pendingAnimal=="" || pendingNonce=="")return;
   if(id!=herdRoot || llGetOwnerKey(id)!=llGetOwner() || !validHerdRoot(herdRoot) || llGetUnixTime()>pendingUntil)return;
   if(llJsonGetValue(message,["type"])!="EQUINE_RESULT" || llJsonGetValue(message,["nonce"])!=pendingNonce || llJsonGetValue(message,["animal"])!=pendingAnimal)return;
   if(llJsonGetValue(message,["valid"])=="1" && llListFindList(assigned,[pendingAnimal])<0 && llGetListLength(assigned)<stalls){assigned += [pendingAnimal];save();llOwnerSay("Verified horse/donkey assigned to stable.");}
   else llOwnerSay("Herd rejected animal or stable is full.");
   pendingAnimal="";pendingNonce="";pendingUntil=0;return;
  }
  if(id!=llGetOwner())return;
  if(message=="More"){menuPage=1;menu(id);return;}
  if(message=="Back"){menuPage=0;menu(id);return;}
  if(message=="Status"){if(herdRoot!=NULL_KEY && !validHerdRoot(herdRoot))llOwnerSay("Warning: saved Herd object is no longer nearby or same-owner.");report(id);menu(id);return;}
  if(message=="Set Herd"){if(pendingWater>0){llOwnerSay("Cannot change Herd while a water delivery is pending.");menu(id);return;}pendingHerd=TRUE;llTextBox(id,"Paste the Herd root object UUID. Must belong to the same owner and region.",CHANNEL);return;}
  if(pendingHerd){pendingHerd=FALSE;if(pendingWater>0){llOwnerSay("Finish the pending water delivery before changing Herd.");menu(id);return;}if(validUUID(message) && validHerdRoot((key)message)){key nextHerd=(key)message;if(nextHerd!=herdRoot){assigned=[];pendingAnimal="";pendingNonce="";pendingUntil=0;careEnabled=FALSE;llOwnerSay("Herd changed: old stall assignments cleared and care monitoring paused. Reverify animals against the new Herd.");}herdRoot=nextHerd;save();llOwnerSay("Same-owner, nearby Herd target saved. Verify each equine before assignment.");}else llOwnerSay("Herd target must be an existing same-owner object within 96 m.");menu(id);return;}
  if(message=="Assign UUID"){if(pendingAnimal!=""){llOwnerSay("Wait for the previous verification to finish.");return;}pendingAssignment=TRUE;llTextBox(id,"Paste an existing Herd animal UUID. This is a local assignment, not yet verified against the Herd controller.",CHANNEL);return;}
  if(pendingAssignment && !validUUID(message)){pendingAssignment=FALSE;llOwnerSay("Invalid animal UUID; no assignment saved.");menu(id);return;}
  if(pendingAssignment && validUUID(message)){
   pendingAssignment=FALSE;
   if(llListFindList(assigned,[message])>=0)llOwnerSay("Animal already assigned.");
   else if(llGetListLength(assigned)>=stalls)llOwnerSay("Stable full.");
   else if(!validHerdRoot(herdRoot))llOwnerSay("Set a valid same-owner Herd first.");
   else {pendingAnimal=message;pendingNonce=(string)llGenerateKey();pendingUntil=llGetUnixTime()+20;llRegionSayTo(herdRoot,herdChannel,llList2Json(JSON_OBJECT,["type","EQUINE_CHECK","animal",pendingAnimal,"nonce",pendingNonce]));llOwnerSay("Checking animal with Herd controller…");}
   menu(id);return;
  }
  if(message=="Send water" || message=="Send feed"){
   if(pendingWater>0){llOwnerSay("Previous supply delivery still pending.");menu(id);return;}
   if(!transferInRange()){llOwnerSay("Supply delivery requires the same-owner Herd within 8 m.");menu(id);return;}
   string kind="WATER";if(message=="Send feed")kind="FEED";
   if((kind=="WATER" && water<10) || (kind=="FEED" && hay<10)){llOwnerSay("At least 10 units of selected supply required.");menu(id);return;}
   if(transferSeq>=999999999){llOwnerSay("Transfer sequence exhausted; manual migration required.");menu(id);return;}
   pendingWater=10;pendingKind=kind;pendingStarted=llGetUnixTime();transferAttempts=0;transferSeq+=1;save();lastWaterSend=0;llOwnerSay(kind+" delivery reserved; awaiting Herd acknowledgment.");menu(id);return;
  }
  if(message=="Care on"){
   if(!validHerdRoot(herdRoot)){llOwnerSay("Cannot start monitoring: configure a nearby same-owner Herd.");menu(id);return;}
   if(llGetListLength(assigned)==0){llOwnerSay("Cannot start monitoring: verify and assign an equine first.");menu(id);return;}
   careEnabled=TRUE;lastCare=llGetUnixTime();
   llOwnerSay("Care monitoring enabled. Herd remains authoritative; stable supplies are not deducted.");
  }
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
  if(careEnabled && !validHerdRoot(herdRoot)){careEnabled=FALSE;save();llOwnerSay("Stable monitoring paused: linked Herd is missing, too far away, or has a different owner.");}
  if(pendingWater>0 && transferInRange() && llGetUnixTime()-lastWaterSend>=10){
   lastWaterSend=llGetUnixTime();
   if(transferAttempts<1000000)transferAttempts+=1;
   if(transferAttempts==1 || (transferAttempts%30)==0)llOwnerSay("Pending "+pendingKind+" delivery: attempt "+(string)transferAttempts+". No stock debited until ACK.");
   save();
   llRegionSayTo(herdRoot,NET,llList2Json(JSON_OBJECT,["v",1,"op","LOAD","target",(string)herdRoot,"stream",transferStream,"seq",transferSeq,"qty",pendingWater,"kind",pendingKind]));
  }
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
  // Stable monitoring is observational until the Herd supply protocol is implemented.
  // No independent feed, water, bedding or manure accounting occurs here.
  integer hayNeeded=n*2;
  integer waterNeeded=n*3;
  if(hay<hayNeeded || water<waterNeeded){
   careEnabled=FALSE;
   llOwnerSay("Stable monitoring paused: displayed supplies are low. Herd care is unaffected.");
  }
  lastSupplyAudit=now;
  lastCare=now;
  save();
 }
}
