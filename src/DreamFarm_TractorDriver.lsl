// Romeo Dream - physical vehicle driver. Same ROOT as DreamFarm_Machine.
// Owner sits on root, grants controls; arrows/WASD drive, reverse and steer.
// Every second requires a saved fuel authorization. Fail-closed on lost lease.
key driver;key pending;integer issued;integer lease;integer controls;
integer granted;float throttle;float steering;float speedLimit=4.0;
stop()
{
    llSetVehicleVectorParam(VEHICLE_LINEAR_MOTOR_DIRECTION,ZERO_VECTOR);
    llSetVehicleVectorParam(VEHICLE_ANGULAR_MOTOR_DIRECTION,ZERO_VECTOR);
    llSetStatus(STATUS_PHYSICS,FALSE);lease=0;
}
seat()
{
    key sitting=llAvatarOnSitTarget();
    if(sitting!=llGetOwner())
    {if(sitting!=NULL_KEY)llUnSit(sitting);stop();llReleaseControls();driver=NULL_KEY;granted=FALSE;pending=NULL_KEY;return;}
    if(driver!=sitting || !granted)
    {stop();driver=sitting;llRequestPermissions(driver,PERMISSION_TAKE_CONTROLS);}
}
motor()
{
    if(!granted || driver!=llAvatarOnSitTarget() || driver!=llGetOwner() || llGetUnixTime()>=lease){stop();return;}
    float speed=throttle*speedLimit;if(throttle<0.0){float reverse=speedLimit;if(reverse>2.0)reverse=2.0;speed=throttle*reverse;}
    llSetStatus(STATUS_PHYSICS,TRUE);
    llSetVehicleVectorParam(VEHICLE_LINEAR_MOTOR_DIRECTION,<speed,0.0,0.0>);
    llSetVehicleVectorParam(VEHICLE_ANGULAR_MOTOR_DIRECTION,<0.0,0.0,steering*0.7>);
}
default
{
    state_entry()
    {
        llSetVehicleType(VEHICLE_TYPE_CAR);
        llSetVehicleVectorParam(VEHICLE_LINEAR_FRICTION_TIMESCALE,<2.0,0.2,2.0>);
        llSetVehicleVectorParam(VEHICLE_ANGULAR_FRICTION_TIMESCALE,<0.2,0.2,0.5>);
        llSetVehicleFloatParam(VEHICLE_LINEAR_MOTOR_TIMESCALE,0.5);
        llSetVehicleFloatParam(VEHICLE_LINEAR_MOTOR_DECAY_TIMESCALE,0.5);
        llSetVehicleFloatParam(VEHICLE_ANGULAR_MOTOR_TIMESCALE,0.4);
        llSetVehicleFloatParam(VEHICLE_ANGULAR_MOTOR_DECAY_TIMESCALE,0.4);
        llSetVehicleFloatParam(VEHICLE_VERTICAL_ATTRACTION_EFFICIENCY,0.8);
        llSetVehicleFloatParam(VEHICLE_VERTICAL_ATTRACTION_TIMESCALE,1.0);
        llSitTarget(<0.0,0.0,0.6>,ZERO_ROTATION);stop();seat();llSetTimerEvent(1.0);
    }
    on_rez(integer p){llResetScript();}
    changed(integer c)
    {
        if(c & CHANGED_OWNER)llResetScript();
        if(c & CHANGED_REGION){stop();pending=NULL_KEY;granted=FALSE;}
        if(c & (CHANGED_LINK|CHANGED_REGION))seat();
    }
    run_time_permissions(integer p)
    {
        if((p & PERMISSION_TAKE_CONTROLS) && llGetPermissionsKey()==driver && driver==llGetOwner() && driver==llAvatarOnSitTarget())
        {granted=TRUE;llTakeControls(CONTROL_FWD|CONTROL_BACK|CONTROL_LEFT|CONTROL_RIGHT|CONTROL_ROT_LEFT|CONTROL_ROT_RIGHT,TRUE,FALSE);}
        else {granted=FALSE;stop();}
    }
    control(key who,integer held,integer change)
    {
        if(who!=driver || !granted)return;
        throttle=0.0;steering=0.0;
        if(held & CONTROL_FWD)throttle+=1.0;if(held & CONTROL_BACK)throttle-=1.0;
        if(held & (CONTROL_LEFT|CONTROL_ROT_LEFT))steering+=1.0;
        if(held & (CONTROL_RIGHT|CONTROL_ROT_RIGHT))steering-=1.0;
        motor();
    }
    timer()
    {
        if(driver!=llAvatarOnSitTarget()){seat();return;}
        if(!granted || driver==NULL_KEY){stop();return;}
        if(llGetUnixTime()>=lease)stop();
        if(pending==NULL_KEY || llGetUnixTime()-issued>3){pending=llGenerateKey();issued=llGetUnixTime();}
        llMessageLinked(LINK_THIS,48200,llList2Json(JSON_OBJECT,["v",1,"actor",(string)driver,"load",(integer)(llFabs(throttle)*1000.0)]),pending);
    }
    link_message(integer sender,integer number,string text,key id)
    {
        if(sender!=llGetLinkNumber())return;
        if(number==48202){stop();pending=NULL_KEY;return;}
        if(number!=48201 || id!=pending || pending==NULL_KEY || llJsonValueType(text,[])!=JSON_OBJECT || llJsonGetValue(text,["v"])!="1")return;
        if(llJsonGetValue(text,["run"])!="1"){stop();pending=NULL_KEY;return;}
        integer until=(integer)llJsonGetValue(text,["until"]);
        if(until<=llGetUnixTime() || until>llGetUnixTime()+2){stop();pending=NULL_KEY;return;}
        string cap=llJsonGetValue(text,["speed"]);speedLimit=4.0;
        if(cap!=JSON_INVALID)
        {speedLimit=(float)cap;if(llJsonValueType(text,["speed"])!=JSON_NUMBER || speedLimit<=0.0 || speedLimit>4.0){stop();pending=NULL_KEY;return;}}
        lease=until;pending=NULL_KEY;motor();
    }
}
