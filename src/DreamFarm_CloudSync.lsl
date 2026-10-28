// Dream Farming optional telemetry companion. Project/creator: Romeo Dream.
// Install beside ONE root controller. Disabled until privately configured.
// Per-object credential only: never put ADMIN_TOKEN in a Second Life object.
string API_URL="https://dream-farming.romeo-hazemoon.workers.dev";
string OBJECT_TOKEN="";
integer VIEW=48100;
integer revision=-1;
integer blocked=FALSE;
integer requestAt=0;
integer nextAttempt=0;
integer observedAt=0;
integer syncedAt=0;
integer failures=0;
key requestId=NULL_KEY;
string mode="";
string latest="";
integer configured(){
 if(llSubStringIndex(API_URL,"https://")!=0 || llStringLength(OBJECT_TOKEN)<24 || llStringLength(OBJECT_TOKEN)>128)return FALSE;
 string chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-";integer i;
 for(i=0;i<llStringLength(OBJECT_TOKEN);++i)if(llSubStringIndex(chars,llGetSubString(OBJECT_TOKEN,i,i))<0)return FALSE;
 return TRUE;
}
integer validCount(string raw,string field){
 if(llJsonValueType(raw,[field])!=JSON_NUMBER)return FALSE;
 float v=(float)llJsonGetValue(raw,[field]);integer n=(integer)v;
 return v==(float)n && n>=0 && n<=1000000;
}
observe(string raw){
 if(llStringLength(raw)>1000 || llJsonValueType(raw,[])!=JSON_OBJECT)return;
 if(llJsonGetValue(raw,["fault"])!="0"){latest="";observedAt=0;return;}
 string kind=llJsonGetValue(raw,["kind"]);string metric="";integer count=0;
 if(kind=="HERD" && validCount(raw,"living")){kind="livestock";metric="animals";count=(integer)llJsonGetValue(raw,["living"]);}
 else if(kind=="FIELD" && validCount(raw,"crop")){kind="field";metric="active_crops";if((integer)llJsonGetValue(raw,["crop"])>0)count=1;}
 else if(kind=="MACHINE"){kind="equipment";metric="equipment";count=1;}
 else return;
 string metrics=llList2Json(JSON_OBJECT,[metric,count]);
 latest=llList2Json(JSON_OBJECT,["kind",kind,"metrics",JSON_NULL,"observed_at",llGetUnixTime(),"object_id",(string)llGetKey(),"owner_uuid",(string)llGetOwner()]);
 latest=llJsonSetValue(latest,["metrics"],metrics);observedAt=llGetUnixTime();
}
backoff(){
 ++failures;if(failures>5)failures=5;
 nextAttempt=llGetUnixTime()+30*(1<<failures);
}
request(string method,string path,string body){
 mode=method;requestAt=llGetUnixTime();
 requestId=llHTTPRequest(API_URL+path,[HTTP_METHOD,method,HTTP_MIMETYPE,"application/json",HTTP_CUSTOM_HEADER,"Authorization","Bearer "+OBJECT_TOKEN,HTTP_BODY_MAXLENGTH,4096],body);
 if(requestId==NULL_KEY){mode="";backoff();}
}
default{
 state_entry(){
  llSetTimerEvent(30.0);
  if(configured()){
   string binding=llList2Json(JSON_ARRAY,[(string)llGetOwner(),(string)llGetKey()]);
   string saved=llLinksetDataRead("dreamfarm:cloud:binding");
   if(saved!="" && saved!=binding){blocked=TRUE;llOwnerSay("Cloud identity changed: provision a new credential in a fresh object.");return;}
   integer result=llLinksetDataWrite("dreamfarm:cloud:binding",binding);
   if(result!=LINKSETDATA_OK && result!=LINKSETDATA_NOUPDATE){blocked=TRUE;llOwnerSay("Cloud binding save failed; telemetry locked.");return;}
   llOwnerSay("Cloud telemetry enabled; local farming continues independently.");llMessageLinked(LINK_THIS,VIEW+1,"",NULL_KEY);}
  else llOwnerSay("Cloud telemetry disabled. Configure a private per-object credential to enable; farming works locally.");
 }
 changed(integer change){if(change & CHANGED_OWNER){blocked=TRUE;OBJECT_TOKEN="";requestId=NULL_KEY;llOwnerSay("Owner changed: telemetry locked. Remove this script and provision a fresh credential.");}}
 link_message(integer sender,integer number,string text,key id){if(sender==llGetLinkNumber() && number==VIEW)observe(text);}
 timer(){
  integer now=llGetUnixTime();
  if(blocked || !configured())return;
  if(requestId!=NULL_KEY){if(now-requestAt<90)return;requestId=NULL_KEY;mode="";revision=-1;backoff();return;}
  if(now<nextAttempt)return;
  if(revision<0){request("GET","/v1/state","");return;}
  // Ask the local controller for fresh measurements; never publish invented totals.
  llMessageLinked(LINK_THIS,VIEW+1,"",NULL_KEY);
  if(latest=="" || now-observedAt>90)return;
  string body=llList2Json(JSON_OBJECT,["revision",revision,"state",JSON_NULL]);
  body=llJsonSetValue(body,["state"],latest);request("POST","/v1/state/sync",body);
 }
 http_response(key id,integer status,list metadata,string body){
  if(blocked || requestId==NULL_KEY || id!=requestId)return;
  string operation=mode;requestId=NULL_KEY;mode="";
  if(status==401 || status==403){blocked=TRUE;llOwnerSay("Cloud credential rejected. Telemetry paused; local farming unaffected.");return;}
  if(status==409){revision=-1;backoff();return;}
  if(status!=200 || llJsonValueType(body,[])!=JSON_OBJECT || !validCount(body,"revision")){backoff();return;}
  integer next=(integer)llJsonGetValue(body,["revision"]);
  if(operation=="POST" && (llJsonGetValue(body,["ok"])!=JSON_TRUE || next!=revision+1)){revision=-1;backoff();return;}
  revision=next;failures=0;nextAttempt=llGetUnixTime()+60;
  if(operation=="POST")syncedAt=llGetUnixTime();
 }
}
