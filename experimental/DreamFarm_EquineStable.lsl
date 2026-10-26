// Dream Farming equine stable controller — alpha companion for Horse/Donkey herds.
// Root prim: stable object. Link horse/donkey mesh components as visual children.
// This script does not move or animate unrigged meshes.
integer CHANNEL=-918247;
integer listenHandle;
integer ownerOnly(key who){return who==llGetOwner();}
string stableName="Dream Stable";
integer stalls=4;
integer occupied=0;
integer hay=0;
integer water=0;
integer bedding=0;
integer manure=0;
integer MAX_STOCK=10000;
integer clampInt(integer v,integer lo,integer hi){if(v<lo)return lo;if(v>hi)return hi;return v;}
report(key who){
 llRegionSayTo(who,0,stableName+" | Stalls "+(string)occupied+"/"+(string)stalls+" | Hay "+(string)hay+" | Water "+(string)water+" | Bedding "+(string)bedding+" | Manure "+(string)manure+". Equine assignments are manual until Herd integration.");
}
menu(key who){
 llDialog(who,stableName+" (owner-operated alpha)",["Status","Add hay","Add water","Add bedding","Muck out","Stalls +1","Stalls -1","Close"],CHANNEL);
}
default {
 state_entry(){
  listenHandle=llListen(CHANNEL,"",llGetOwner(),"");
  llSetText("Dream Stable | Equine care alpha",<1.0,0.5,0.8>,1.0);
 }
 on_rez(integer start){llResetScript();}
 changed(integer change){if(change & CHANGED_OWNER)llResetScript();}
 touch_start(integer count){key who=llDetectedKey(0);if(ownerOnly(who))menu(who);}
 listen(integer channel,string name,key id,string message){
  if(!ownerOnly(id))return;
  if(message=="Status")report(id);
  else if(message=="Add hay")hay=clampInt(hay+25,0,MAX_STOCK);
  else if(message=="Add water")water=clampInt(water+50,0,MAX_STOCK);
  else if(message=="Add bedding")bedding=clampInt(bedding+20,0,MAX_STOCK);
  else if(message=="Muck out"){manure=0;llOwnerSay("Stable muck-out recorded locally. No manure delivered to other farm objects.");}
  else if(message=="Stalls +1")stalls=clampInt(stalls+1,1,8);
  else if(message=="Stalls -1")stalls=clampInt(stalls-1,1,8);
  if(message!="Close"){report(id);menu(id);}
 }
}
