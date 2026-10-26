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
list assigned=[]; // animal UUID strings, manually registered by owner
string PREFIX="dreamfarm:stable:v2:";
integer clampInt(integer v,integer lo,integer hi){if(v<lo)return lo;if(v>hi)return hi;return v;}
integer validUUID(string value){return (key)value!=NULL_KEY && llStringLength(value)==36;}
save(){
 llLinksetDataWrite(PREFIX+"stalls",(string)stalls);
 llLinksetDataWrite(PREFIX+"hay",(string)hay);
 llLinksetDataWrite(PREFIX+"water",(string)water);
 llLinksetDataWrite(PREFIX+"bedding",(string)bedding);
 llLinksetDataWrite(PREFIX+"manure",(string)manure);
 llLinksetDataWrite(PREFIX+"assigned",llList2Json(JSON_ARRAY,assigned));
}
load(){
 string value=llLinksetDataRead(PREFIX+"stalls");
 if(value==""){save();return;}
 stalls=clampInt((integer)value,1,8);
 hay=clampInt((integer)llLinksetDataRead(PREFIX+"hay"),0,MAX_STOCK);
 water=clampInt((integer)llLinksetDataRead(PREFIX+"water"),0,MAX_STOCK);
 bedding=clampInt((integer)llLinksetDataRead(PREFIX+"bedding"),0,MAX_STOCK);
 manure=clampInt((integer)llLinksetDataRead(PREFIX+"manure"),0,MAX_STOCK);
 string raw=llLinksetDataRead(PREFIX+"assigned");
 if(llJsonValueType(raw,[])==JSON_ARRAY)assigned=llJson2List(raw);
 else assigned=[];
 if(llGetListLength(assigned)>stalls)assigned=llList2List(assigned,0,stalls-1);
}
report(key who){
 llRegionSayTo(who,0,"Dream Stable | Stalls "+(string)llGetListLength(assigned)+"/"+(string)stalls+" | Hay "+(string)hay+" | Water "+(string)water+" | Bedding "+(string)bedding+" | Manure "+(string)manure+" | Assignments "+llList2CSV(assigned));
}
menu(key who){
 llDialog(who,"Dream Stable (owner-operated experimental care)",["Status","Add hay","Add water","Add bedding","Muck out","Assign UUID","Release last","Stalls +1","Stalls -1","Close"],CHANNEL);
}
default {
 state_entry(){
  load();
  listenHandle=llListen(CHANNEL,"",llGetOwner(),"");
  llSetText("Dream Stable | Equine care prototype",<1.0,0.5,0.8>,1.0);
 }
 on_rez(integer start){llResetScript();}
 changed(integer change){if(change & CHANGED_OWNER)llResetScript();}
 touch_start(integer count){key who=llDetectedKey(0);if(who==llGetOwner())menu(who);}
 listen(integer channel,string name,key id,string message){
  if(id!=llGetOwner())return;
  if(message=="Status"){report(id);menu(id);return;}
  if(message=="Assign UUID"){llTextBox(id,"Paste an existing Herd animal UUID. This is a local assignment, not yet verified against the Herd controller.",CHANNEL);return;}
  if(validUUID(message)){
   if(llListFindList(assigned,[message])>=0)llOwnerSay("Animal already assigned.");
   else if(llGetListLength(assigned)>=stalls)llOwnerSay("Stable full.");
   else {assigned += [message];save();llOwnerSay("Stall assignment saved locally.");}
   menu(id);return;
  }
  if(message=="Add hay")hay=clampInt(hay+25,0,MAX_STOCK);
  else if(message=="Add water")water=clampInt(water+50,0,MAX_STOCK);
  else if(message=="Add bedding")bedding=clampInt(bedding+20,0,MAX_STOCK);
  else if(message=="Muck out"){manure=0;llOwnerSay("Local muck-out only; no manure transferred to compost.");}
  else if(message=="Release last"){
   if(llGetListLength(assigned)>0)assigned=llDeleteSubList(assigned,-1,-1);
  }
  else if(message=="Stalls +1")stalls=clampInt(stalls+1,1,8);
  else if(message=="Stalls -1"){
   if(stalls>llGetListLength(assigned))stalls=clampInt(stalls-1,1,8);
   else llOwnerSay("Release an assigned animal before reducing stall capacity.");
  }
  else if(message=="Close")return;
  else {llOwnerSay("Invalid command or UUID.");menu(id);return;}
  save();report(id);menu(id);
 }
}
