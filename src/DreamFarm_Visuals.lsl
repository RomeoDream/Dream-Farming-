// Display-only. Add alongside a controller in the ROOT prim.
// Optional child names: DF:Stage:0 ... DF:Stage:5. 0 bare,1 seed,2 sprout,
// 3 growing,4 harvest-ready,5 dead. Unnamed children are untouched.
integer VIEW=48100;
default
{
    state_entry(){llMessageLinked(LINK_SET,VIEW+1,"",NULL_KEY);}
    changed(integer change){if(change & CHANGED_LINK)llMessageLinked(LINK_SET,VIEW+1,"",NULL_KEY);}
    link_message(integer sender,integer number,string msg,key id)
    {
        if(sender!=llGetLinkNumber() || number!=VIEW || llJsonValueType(msg,[])!=JSON_OBJECT)return;
        if(llJsonGetValue(msg,["kind"])!="FIELD")return;
        if(llJsonValueType(msg,["stage"])!=JSON_NUMBER)return;
        integer stage=(integer)llJsonGetValue(msg,["stage"]);if(stage<0 || stage>5)return;
        integer i;for(i=2;i<=llGetNumberOfPrims();++i)
        {
            string name=llGetLinkName(i);integer j;
            for(j=0;j<=5;++j)if(name=="DF:Stage:"+(string)j)llSetLinkAlpha(i,(float)(j==stage),ALL_SIDES);
        }
    }
}
