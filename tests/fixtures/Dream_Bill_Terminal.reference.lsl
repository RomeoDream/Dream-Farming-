// Dream Banking 1.2: durable billing terminal/adapter. Set bank and business UUIDs.
// Register this ROOT as BILL. Its owner must own the configured business.
// Trusted same-root scripts: 42001 issue; 42003 query; 42002 saved status response.
key BANK_ROOT=NULL_KEY;
string BUSINESS_ID="";
integer NET=-80425191;
integer cursor;
integer locked;
integer handle;
integer channel;
integer expires;
string phase;
string get(string s,string k) { string v=llJsonGetValue(s,[k]);if(v==JSON_INVALID)return "";return v; }
integer uuid(string s) {
    if(llStringLength(s)!=36 || (key)s==NULL_KEY)return FALSE;
    integer i;for(i=0;i<36;++i) {
        string c=llGetSubString(s,i,i);
        if(i==8 || i==13 || i==18 || i==23) { if(c!="-")return FALSE; }
        else if(llSubStringIndex("0123456789abcdef",c)<0)return FALSE;
    }
    return TRUE;
}
integer configured() { return uuid((string)BANK_ROOT) && uuid(BUSINESS_ID); }
integer write(string k,string v) { llLinksetDataWrite(k,v);if(llLinksetDataRead(k)!=v) { locked=TRUE;llOwnerSay("Billing storage fault. Preserve requests and resolve before continuing.");return FALSE; }return TRUE; }
string binding() { return (string)llGetOwner()+"|"+(string)llGetKey()+"|"+(string)BANK_ROOT+"|"+BUSINESS_ID; }
send(string id,integer create) {
    string d=llLinksetDataRead("DBB:req:"+id);if(d=="")return;
    if(!create)d=llList2Json(JSON_OBJECT,["v",1,"op","BILL_STATUS","req",(string)llGenerateKey(),"bill",id]);
    llRegionSayTo(BANK_ROOT,NET,d);
}
issue(string data) {
    string id=get(data,"bill");string payer=get(data,"payer");string raw=get(data,"amount");integer n=(integer)raw;string days=get(data,"days");integer period=(integer)days;
    if(!uuid(id) || !uuid(payer) || (string)n!=raw || n<1 || n>100000000 || (string)period!=days || period<1 || period>365 ||
        llStringLength(get(data,"description"))<3 || llStringLength(get(data,"description"))>120) { llOwnerSay("Invalid bill: UUIDs, integer cents, days 1-365, description 3-120 characters required.");return; }
    string d=llList2Json(JSON_OBJECT,["v",1,"op","BILL_CREATE","req",id,"bill",id,"business",BUSINESS_ID,"payer",payer,"amount",n,"days",period,"description",get(data,"description")]);
    string saved=llLinksetDataRead("DBB:req:"+id);
    if(saved!="" && saved!=d) { llOwnerSay("Bill ID conflict. Keep the original request.");return; }
    if(saved=="") { if(!write("DBB:req:"+id,d))return; }
    send(id,TRUE);
}
prompt(string next,integer box) {
    if(handle)llListenRemove(handle);channel=-100000-(integer)llFrand(1000000000.0);handle=llListen(channel,"",llGetOwner(),"");expires=llGetUnixTime()+120;phase=next;
    if(box) {
        string hint="Enter a saved bill UUID.";
        if(next=="ISSUE")hint="Customer UUID|amount in CENTS|days until due|description. Example amount: 2500 = RP$25.00. No automatic debit.";
        llTextBox(llGetOwner(),hint+"\nType Cancel to close.",channel);
    }
    else llDialog(llGetOwner(),"DREAM BILL TERMINAL\nIssue, inspect or safely retry a saved invoice. Customer pays through the bank.",["Issue","Status","Retry","Close"],channel);
}
default {
    state_entry() {
        llListen(NET,"",BANK_ROOT,"");llSetTimerEvent(20.0);llSetPayPrice(PAY_HIDE,[PAY_HIDE,PAY_HIDE,PAY_HIDE,PAY_HIDE]);
        if(!configured()) { locked=TRUE;llOwnerSay("Set BANK_ROOT and BUSINESS_ID first.");return; }
        string b=llLinksetDataRead("DBB:binding");
        if(b=="") { if(!write("DBB:binding",binding()))return; }
        else if(b!=binding()) { locked=TRUE;llOwnerSay("Billing owner/root/config changed. Reconcile retained bills before migration; do not clear data.");return; }
        llSetText("DREAM BILLING\nOwner: touch for invoices\nCustomers: bank > Services > My Bills",<0.2,0.7,1.0>,1.0);
        llOwnerSay("Approve this root as BILL: "+(string)llGetKey());
    }
    on_rez(integer n) { llResetScript(); }
    changed(integer c) { if(c & (CHANGED_OWNER|CHANGED_LINK))llResetScript(); }
    timer() {
        if(handle && llGetUnixTime()>expires) { llListenRemove(handle);handle=0; }
        if(locked)return;
        list keys=llLinksetDataFindKeys("^DBB:req:",cursor,1);if(llGetListLength(keys)==0) { cursor=0;return; }++cursor;
        string d=llLinksetDataRead(llList2String(keys,0));string id=get(d,"bill");string result=llLinksetDataRead("DBB:status:"+id);string status=get(result,"status");
        if(status=="PAID" || status=="CANCELLED" || status=="ERROR")return;
        send(id,result=="");
    }
    touch_start(integer n) { if(!locked && llDetectedKey(0)==llGetOwner())prompt("MENU",FALSE); }
    link_message(integer sender,integer code,string data,key actor) {
        if(locked || sender!=llGetLinkNumber())return;
        if(code==42001)issue(data);
        else if(code==42003) {
            string result=llLinksetDataRead("DBB:status:"+data);
            if(result!="")llMessageLinked(LINK_THIS,42002,result,actor);
            send(data,FALSE);
        }
    }
    listen(integer c,string name,key speaker,string message) {
        if(locked)return;
        if(c==NET) {
            if(speaker!=BANK_ROOT || get(message,"v")!="1")return;
            string id=get(message,"bill");string saved=llLinksetDataRead("DBB:req:"+id);if(saved=="")return;
            string status=get(message,"status");
            if(get(message,"ok")=="1") {
                if(get(message,"amount")!=get(saved,"amount") || get(message,"payer")!=get(saved,"payer") || get(message,"business")!=BUSINESS_ID)return;
                integer paid=(integer)get(message,"paid");
                if((string)paid!=get(message,"paid") || paid<0 || paid>(integer)get(saved,"amount") || (status=="PAID" && paid!=(integer)get(saved,"amount")))return;
                if(llListFindList(["OPEN","PARTIAL","PAID","CANCELLED"],[status])<0)return;
            }
            else status="ERROR";
            string prior=llLinksetDataRead("DBB:status:"+id);
            // A delayed OPEN/PARTIAL reply must not undo a later settled state.
            if(get(message,"ok")!="1" && get(prior,"ok")=="1")return;
            if(get(prior,"status")=="PAID" || get(prior,"status")=="CANCELLED")return;
            if((integer)get(message,"paid")<(integer)get(prior,"paid"))return;
            if(!write("DBB:status:"+id,llJsonSetValue(message,["status"],status)))return;
            llMessageLinked(LINK_THIS,42002,llLinksetDataRead("DBB:status:"+id),(key)get(saved,"payer"));return;
        }
        if(c!=channel || speaker!=llGetOwner() || !handle || llGetUnixTime()>expires)return;
        message=llStringTrim(message,STRING_TRIM);
        if(message=="Close" || message=="Cancel") { llListenRemove(handle);handle=0;return; }
        if(phase=="MENU") { if(message=="Issue")prompt("ISSUE",TRUE);else if(message=="Status")prompt("STATUS",TRUE);else if(message=="Retry")prompt("RETRY",TRUE);return; }
        if(phase=="ISSUE") {
            list f=llParseStringKeepNulls(message,["|"],[]);if(llGetListLength(f)!=4)return;
            string id=(string)llGenerateKey();issue(llList2Json(JSON_OBJECT,["bill",id,"payer",llToLower(llList2String(f,0)),"amount",llList2String(f,1),"days",llList2String(f,2),"description",llList2String(f,3)]));
            llOwnerSay("Bill reference: "+id+". Inspect status before issuing another bill for the same charge.");
        }
        else {
            string result=llLinksetDataRead("DBB:status:"+message);llOwnerSay("Saved bill status: "+get(result,"status")+" | Paid cents: "+get(result,"paid"));send(message,phase=="RETRY");
        }
        llListenRemove(handle);handle=0;
    }
}
