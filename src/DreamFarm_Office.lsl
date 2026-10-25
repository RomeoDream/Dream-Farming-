// Work orders and optional Dream Banking service invoices, in fictional cents.
// Same root: configured Dream_Bill_Terminal, approved as BILL by the bank.
// This office never grants goods or fabricates payments. Job completion is manual.
string DATA="dreamfarm:office:v1";string KIND="FARM OFFICE";
integer SCHEMA=1;integer OUT=17;integer BASE=22;
integer USE_BANK=FALSE;string BUSINESS_ID="";integer queried;
// 8 jobs array;9 selected;10 draft cents;11 draft payer;12 reserved;
// 13 draft due days;14 fully paid service cents;15 completed jobs;16 business binding.
// Job: id,title,assigned avatar,statusValue(0 open/1 active/2 done),bill UUID,
// payer,cents,paid,status,days. Historical records never auto-evicted.
fresh(){S=header()+["[]",0,2500,"",0,7,0,0,BUSINESS_ID]+outbox();}
list migrate(list v){return v;}
list jobs(){return llJson2List(sv(8));}
list job(integer i){return llJson2List(llList2String(jobs(),i));}
putJob(integer i,list j){put(8,[llList2Json(JSON_ARRAY,llListReplaceList(jobs(),[llList2Json(JSON_ARRAY,j)],i,i))]);}
integer validSpecific(list v)
{
    if(USE_BANK && (!uuid(BUSINESS_ID) || llList2String(v,16)!=BUSINESS_ID))return FALSE;
    if(llJsonValueType(llList2String(v,8),[])!=JSON_ARRAY)return FALSE;
    list all=llJson2List(llList2String(v,8));integer n=llGetListLength(all);if(n>16)return FALSE;
    integer i;list ids=[];for(i=0;i<n;++i)
    {
        list j=llJson2List(llList2String(all,i));string id=llList2String(j,0);string bill=llList2String(j,4);
        if(llGetListLength(j)!=10 || !uuid(id) || llListFindList(ids,[id])>=0 || !uuid(llList2String(j,2)))return FALSE;ids+=[id];
        if(llStringLength(llList2String(j,1))<3 || llStringLength(llList2String(j,1))>80 || !whole(j,3,0,2))return FALSE;
        if(!whole(j,6,0,100000000) || !whole(j,7,0,llList2Integer(j,6)) || !whole(j,9,1,365))return FALSE;
        if(bill!="" && (!uuid(bill) || !uuid(llList2String(j,5)) || llList2Integer(j,6)<1))return FALSE;
        if(llListFindList(["NONE","PENDING","OPEN","PARTIAL","PAID","CANCELLED","ERROR"],[llList2String(j,8)])<0)return FALSE;
        if(llList2String(j,8)=="PAID" && llList2Integer(j,7)!=llList2Integer(j,6))return FALSE;
    }
    return whole(v,9,0,15) && (n==0 || llList2Integer(v,9)<n) && whole(v,10,1,100000000) && (llList2String(v,11)=="" || uuid(llList2String(v,11))) && whole(v,12,0,0) && whole(v,13,1,365) && whole(v,14,0,2000000000) && whole(v,15,0,16);
}
tick(float dt){}
string summary()
{
    string t="Work orders "+(string)llGetListLength(jobs())+" / 16 | Completed "+(string)iv(15)+"\nFully paid service invoices: "+(string)iv(14)+" RP cents";
    if(llGetListLength(jobs()))
    {list j=job(iv(9));t+="\n"+llList2String(j,1)+" | "+llList2String(["OPEN","ACTIVE","DONE"],llList2Integer(j,3))+"\nAssigned "+llList2String(j,2)+"\nBill "+llList2String(j,8)+" | "+llList2String(j,7)+" / "+llList2String(j,6)+" cents";}
    return t;
}
list buttons(string p)
{if(p=="settings")return ["Pause","Resume","Back","Close"];return ["New work order","Next job","Start job","Finish job","Invoice details","Issue invoice","Retry invoice","Status","Settings","Close"];}
string action(string c)
{
    if(page=="newjob")
    {
        page="main";list f=llParseStringKeepNulls(c,["|"],[]);string title=llList2String(f,0);string who=llList2String(f,1);
        if(who=="")who=(string)llGetOwner();
        if(llGetListLength(f)>2 || llStringLength(title)<3 || llStringLength(title)>80 || !uuid(who))return "Use title (3-80 characters)|worker avatar UUID.";
        if(llGetListLength(jobs())>=16)return "Ledger full; retain this office as history and start a new office.";
        list all=jobs();all+=[llList2Json(JSON_ARRAY,[(string)llGenerateKey(),title,who,0,"","",0,0,"NONE",7])];put(8,[llList2Json(JSON_ARRAY,all)]);put(9,[llGetListLength(all)-1]);return "Work order saved.";
    }
    if(page=="invoice")
    {
        page="main";list f=llParseStringKeepNulls(c,["|"],[]);string payer=llList2String(f,0);string amount=llList2String(f,1);string days=llList2String(f,2);
        if(llGetListLength(f)!=3 || !uuid(payer) || (string)((integer)amount)!=amount || (integer)amount<1 || (integer)amount>100000000 || (string)((integer)days)!=days || (integer)days<1 || (integer)days>365)return "Use payer UUID|positive integer cents|due days 1-365.";
        put(10,[(integer)amount]);put(11,[payer]);put(13,[(integer)days]);return "Invoice DRAFT: payer "+payer+", "+amount+" cents, "+days+" days. Issue invoice saves an immutable request; customer must pay at the bank.";
    }
    if(c=="New work order"){page="newjob";return "";}if(c=="Invoice details"){page="invoice";return "";}
    integer n=llGetListLength(jobs());if(n==0)return "Create a work order first.";
    if(c=="Next job"){put(9,[(iv(9)+1)%n]);return "";}
    list j=job(iv(9));
    if(c=="Start job" || c=="Finish job")
    {
        if(visitor!=llGetOwner() && visitor!=(key)llList2String(j,2))return "Only the assigned worker or owner may update this work order.";
        integer statusValue=llList2Integer(j,3);if(c=="Start job" && statusValue==0)j=llListReplaceList(j,[1],3,3);
        if(c=="Finish job" && statusValue<2){j=llListReplaceList(j,[2],3,3);put(15,[iv(15)+1]);}
        putJob(iv(9),j);return "Work-order status saved. Completion is an owner/worker report.";
    }
    if(c=="Issue invoice")
    {
        if(!USE_BANK)return "Banking disabled. Configure this office and the bank adapter before issuing bills.";
        if(llList2Integer(j,3)!=2 || llList2String(j,4)!="" || !uuid(sv(11)))return "Complete the job and enter invoice details. An existing bill is never replaced.";
        j=llListReplaceList(j,[(string)llGenerateKey(),sv(11),iv(10),0,"PENDING",iv(13)],4,9);putJob(iv(9),j);queried=0;return "Stable invoice saved. Issuing does not debit the customer.";
    }
    if(c=="Retry invoice"){queried=0;return "Retry/query will reuse the original saved bill.";}
    if(c=="Status")return summary();return "";
}
service()
{
    if(fault || iv(4) || !USE_BANK || llGetUnixTime()-queried<30)return;queried=llGetUnixTime();
    integer i;for(i=0;i<llGetListLength(jobs());++i)
    {
        list j=job(i);string id=llList2String(j,4);string statusValue=llList2String(j,8);
        if(id!="" && statusValue!="PAID" && statusValue!="CANCELLED")
        {
            if(statusValue=="PENDING" || statusValue=="ERROR")llMessageLinked(LINK_THIS,42001,llList2Json(JSON_OBJECT,["bill",id,"payer",llList2String(j,5),"amount",llList2Integer(j,6),"days",llList2Integer(j,9),"description","Farm service: "+llList2String(j,1)]),(key)llList2String(j,5));
            llMessageLinked(LINK_THIS,42003,id,(key)llList2String(j,5));
        }
    }
}
extraLink(integer sender,integer number,string text,key actor)
{
    if(fault || !USE_BANK || sender!=llGetLinkNumber() || number!=42002 || llStringLength(text)>1000 || llJsonValueType(text,[])!=JSON_OBJECT || llJsonGetValue(text,["v"])!="1" || llJsonGetValue(text,["ok"])!="1" || llJsonGetValue(text,["business"])!=BUSINESS_ID)return;
    integer i;for(i=0;i<llGetListLength(jobs());++i)
    {
        list j=job(i);
        if(llList2String(j,4)!="" && llList2String(j,4)==llJsonGetValue(text,["bill"]))
        {
            if(llList2String(j,8)=="PAID" || llList2String(j,8)=="CANCELLED")return;
            if(llJsonGetValue(text,["payer"])!=llList2String(j,5) || llJsonGetValue(text,["amount"])!=(string)llList2Integer(j,6))return;
            string statusValue=llJsonGetValue(text,["status"]);integer paid=(integer)llJsonGetValue(text,["paid"]);
            if((string)paid!=llJsonGetValue(text,["paid"]) || paid<llList2Integer(j,7) || paid>llList2Integer(j,6) || llListFindList(["OPEN","PARTIAL","PAID","CANCELLED"],[statusValue])<0)return;
            if(statusValue=="PAID" && paid!=llList2Integer(j,6))return;
            list before=S;if(statusValue=="PAID")put(14,[iv(14)+paid]);
            j=llListReplaceList(j,[paid,statusValue],7,8);putJob(i,j);save(before);return;
        }
    }
}
integer credit(string kind,integer qty){return FALSE;}
string visual(){return llList2Json(JSON_OBJECT,["kind",KIND,"jobs",llGetListLength(jobs()),"fault",fault]);}
extraBoot(){}
integer extraListen(integer c,key who,string msg){return FALSE;}
integer textPage(string p){return p=="newjob" || p=="invoice";}
string textPrompt(){if(page=="newjob")return "Work title (3-80 characters)|assigned worker UUID. Omit UUID to assign yourself.";return "Payer avatar UUID|amount in integer RP cents|due days. Example: avatar-uuid|2500|7";}
transferAck(string kind,integer qty){}
// @include common.lslinc
