component {
	variables.logName="application";
	variables._state="stopped";
    variables.controllerInterval=1000;// interval in ms of the controller thread
    variables.stopInterval=10;
    variables.checkForChangeInterval=10000;
    variables.owner=this; // making owner global
    variables.NL="
";
	public void function init(string id, struct config, component listener) { 
        variables.id=arguments.id;
        try {
            // log
            variables.logName=trim(config.logName?:"");
            if(isEmpty(trim(variables.logName)))variables.logName=readSystemPropOrEnvVar("tasks.event.gateway.log", "application");

            _log("init");
            variables.config=config;
            // package
            variables.package=config.package?:"";
            if(isEmpty(variables.package)) variables.package = readSystemPropOrEnvVar("tasks.event.gateway.package", "org.lucee.cfml.tasks");
            // patch for backward compatibility to older version, because we did depend that this is set by default
            else if(variables.package=="distrocore.tasks") {
                local.tmp = readSystemPropOrEnvVar("tasks.event.gateway.package", "");
                if(!isEmpty(tmp)) variables.package=tmp;
            }
            // template path
            variables.templatePath=config.templatePath?:"";
            if(isEmpty(variables.templatePath)) variables.templatePath = readSystemPropOrEnvVar("tasks.event.gateway.template.path", "");
            if(isEmpty(variables.templatePath)) variables.templatePath = readSystemPropOrEnvVar("tasks.event.gateway.templatePath", "");

            // template path recursive
            variables.templatePathRecursive=config.templatePathRecursive?:"";
            if(isEmpty(variables.templatePathRecursive)) variables.templatePathRecursive = readSystemPropOrEnvVar("tasks.event.gateway.template.path.recursive", "");
            if(isEmpty(variables.templatePathRecursive)) variables.templatePathRecursive = readSystemPropOrEnvVar("tasks.event.gateway.templatePath.recursive", "");
            if(isEmpty(variables.templatePathRecursive)) variables.templatePathRecursive = readSystemPropOrEnvVar("tasks.event.gateway.templatePathRecursive", "");
            if(!isBoolean(variables.templatePathRecursive)) variables.templatePathRecursive = true;
            
            // intervall
            var tmp=int(config.checkForChangeInterval?:-1);
            if(tmp==-1) tmp = int(readSystemPropOrEnvVar("tasks.event.gateway.checkForChangeInterval", 10));
            variables.checkForChangeInterval=tmp*1000;
            
            // intervall no match
            var tmp=int(config.checkForChangeNoMatchInterval?:-1);
            if(tmp==-1) tmp = int(readSystemPropOrEnvVar("tasks.event.gateway.checkForChangeNoMatchInterval", 60));
            variables.checkForChangeNoMatchInterval=tmp*1000;
            

            // setting location (ATM only cache is supported)
            variables.settingLocation=config.settingLocation?:"";
            if(isEmpty(trim(variables.settingLocation))) variables.settingLocation = readSystemPropOrEnvVar("tasks.event.gateway.settingLocation","");
            if(!isEmpty(trim(variables.settingLocation)))variables.settingLocation=trim(variables.settingLocation);
            
            // setting intervall
            var tmp=int(config.checkForChangeSettingInterval?:-1);
            if(tmp==-1) tmp = int(readSystemPropOrEnvVar("tasks.event.gateway.checkForChangeSettingInterval", 0));
            variables.checkForChangeSettingInterval=tmp>0?tmp*1000:0;

            // active
            var tmp = readSystemPropOrEnvVar("tasks.event.gateway.activator", "org.lucee.cfml.tasks.Activator");
            if(!isNull(tmp) && !isEmpty(tmp)) {
                _log("Loading Activator: #tmp#");
                try {
                    variables.activator=createObject("component", tmp);
                }
                catch(e) {
                    _log("failed in init function","error",e);
                }
            }
            else {
                _log("No Activator set");
            }
            if(isNull(variables.activator)) {
                _log("failed to load activator, using instead simple struct collection always returning true","warn");
                variables.activator={active:function (){return true;}};
            }

            _log("init config: "&serialize(config));
        }
        catch(e){
            _log("failed in init function","error",e);
        }
		
	}

	public void function start() {
        try {
			_log("starting");
            
            // just in case Start get triggered without stop before
            if(!isNull(variables.globalSwitch) && variables.globalSwitch.enabled)
                variables.globalSwitch.enabled=false;

			variables.globalSwitch={enabled:true};
            variables._state="starting";
            run(variables.globalSwitch,variables.activator);
            // wait for the runner to start up (that should only take couple ms)
            var countDown=500;
            while(--countDown>0) {
                if(getState()=="running") break;
                sleep(5);
            }
            if(getState()=="running")
                _log("sucessfully started");
            else {
                if (structKeyExists(variables, "activator") && !variables.activator.active()) {
                    _log("stopped because the Activator is inactive.");
                } 
                else {
                    _log("failed to start due to an unknown issue. Please check the logs and configuration for further details.","error");
                }
                
            }
        }
        catch(local.e){
			variables._state="failed";
			_log("failed in start function","error", e);
        }
	}

	public void function stop() {
        _log("stopping");
        if(getState()!="running") {
            _log("could not stop, state was not running","error");
            return;
        }
        // TODO notify controller
		try {
			variables._state="stopping";
            variables.globalSwitch.enabled=false;
			
            // wait for the runner to stop by itself
            _log("stopping: check for stopped","debug");
            var countDown=600;
            while(--countDown>0) {
                if(getState()=="stopped") break;
                sleep(100);
            }
            
            setState("stopped");
        }
        catch(local.e){
			variables._state="failed";
			_log("failed in stop function","error",e);
        }
	}


	public void function restart() {
        _log("restarting");
			
        if(variables._state EQ "running") stop(); 
		start();
	}

	public string function getState() {
		return variables._state;
	}
	public string function setState(state) {
		variables._state=arguments.state;
	}

    public string function sendMessage(struct data) {
        
        var usage= "Send a key ""action"" to trigger a specific action in the gateway, the following actions are supported:
        - state: gives the current state (as string) of the gateway instance
        - info: gives information about the Event Gateway
            ";
        if(!structKeyExists(data,"action")) return usage;
        
        // actions
        switch(data.action) {
            case "state":   return getState();
            case "info":    return serializeJson({
                'logName':variables.logName
                ,'controllerInterval':variables.controllerInterval
                ,'stopInterval':variables.stopInterval
                ,'checkForChangeInterval':variables.checkForChangeInterval
                ,'checkForChangeSettingInterval':variables.checkForChangeSettingInterval?:0
                ,'tasks':getTaskInfo()
            });
            case "pause": return toggle(data.task,true);
            case "resume": return toggle(data.task,false);

        }



        //  no matching action
        cfthrow(message:"invalid action [#data.action#]",detail:usage);
	}
    private function toggle(required string taskName, required boolean paused) {
        var tasks= variables._tasks;
        var task=tasks[taskName];
        if(isNull(local.task)) {
            if(len(tasks)) cfthrow(message:"there is no task with name [#arguments.taskName#], we only have the following tasks [#structKeyList(tasks)#]",detail:usage);
            else cfthrow(message:"there is no task with name [#arguments.taskName#], we have no tasks available",detail:usage);
        }
        task.paused=arguments.paused;
        // when we have a setting location the pause is phyisical stored ad will survive a restart of the Task Engine job
        if(!isEmpty(variables.settingLocation?:"")) {
            setPause(variables.settingLocation, variables.id, task.id, arguments.paused);
        }
        return true;
    }

    private function setPause(required string cache, required string gateway, required string task, required boolean pause) {
        // TOOD optimize for Redis
        var key="task_eventgateway_setting:"&gateway&":"&task;
        var data=cacheGet(id:key,cacheName:cache);
        // new entry
        if(isNull(data)) var data={};
     
        var prev=data.paused?:false;
        data.paused=arguments.pause;
        cachePut(id:key,value:data,timeSpan:1000000 /*2739 years*/ ,cacheName:cache);
        return prev;
    }
    public function getPause(required string cache, required string gateway, required string task) {
        // TOOD optimize for Redis
        var key="task_eventgateway_setting:"&gateway&":"&task;
        var data=cacheGet(id:key,cacheName:cache);
        return data.paused?:false;
    }

    private function getTaskInfo() {
        if(!structKeyExists(variables,"_tasks")) return {};
        
        // define tasks
        var tasks={};
        loop struct=variables._tasks index="local.name" item="local.task" {
            var label=task.properties.task?:"";
            if(isNull(label) || isEmpty(label)) label=ListLast(task.name,"./\");
            tasks[task.name]={
                'name':task.name
                ,'id':task.id?:task.name
                ,'label':label
                ,'description':task.properties.description?:""
                ,'status':task.status
                ,'path':task.path
                ,'lastModified':task.lastModified
                ,'sleepBefore':task.sleepBefore
                ,'sleepAfter':task.sleepAfter
                ,'sleepAfterOnError':task.sleepAfterOnError
                ,'threads':task.threads?:0
                ,'waitForStop':task.waitForStop
                ,'forceStop':task.forceStop
                ,'paused':task.paused?:false
                ,'instances':[]
            };
        }

        // add instances to tasks
        if(!structKeyExists(variables,"_instances")) return tasks;
        loop struct=variables._instances index="local.id" item="local.instance" {
            if(isNull(tasks[instance.task.name].instances) || tasks[instance.task.name].paused) continue;
            arrayAppend(tasks[instance.task.name].instances,{
                'name':instance.name
                ,'id':instance.id?:instance.name
                ,'index':instance.index
                ,'startDate':instance.startDate
                ,'lastExecutionDate':instance.lastExecutionDate?:nullValue()
                ,'lastExecutionTime':instance.lastExecutionTime?:nullValue()
                ,'lastError':instance.lastError?:nullValue()
                ,'iterations':instance.iterations
                ,'errors':instance.errors
                ,'enabled':instance.enabled
            });
        }
        return tasks;
    }

    private void function run(globalSwitch,activator) {
        local.prefix=createUniqueID();
        local.controllerName=local.prefix&":controller";
        local.instances={};
        variables._instances=local.instances;

        // load the necessary data
        try{
            var engine=getEngine();
            var cfcs=loadCFCs();
            var tasks=filter(cfcs,"task");
            var listeners=filter(cfcs,"listener");
        }
        catch(e) {
            var cfcs={};
            var tasks={};
            var listeners={};
            _log("failed loading the Tasks","error",e);
        }
        variables._tasks=local.tasks;

        // starting the controller (this task only check for changes with the Tasks defined)
        thread  name=controllerName controllerName=controllerName instances=instances owner=this 
                engine=engine cfcs=cfcs tasks=tasks listeners=listeners globalSwitch=globalSwitch activator=activator
                prefix=prefix gatewayId=variables.id  checkForChangeInterval=variables.checkForChangeInterval  settingLocation=variables.settingLocation 
                checkForChangeSettingInterval=variables.checkForChangeSettingInterval {
            owner._log("enter controller");
            
            owner.setState("running");
            var first=true;
            var lastCheck=getTickCount();
            var lastCheckSettings=getTickCount();
            while(globalSwitch.enabled && engine.isRunning() && activator.active()) {

                owner._log("running the controller, ATM we have #len(instances)# task instances","debug");
                try {
                    
                    if(first) {
                        loop struct=tasks index="cfcName" item="local.el" {
                            // read task paused setting on the first run
                            if(!isEmpty(settingLocation)) {
                                try {
                                    var paused=owner.getPause(settingLocation, (variables.id?:""), (el.id?:""));
                                    el.paused=paused?:false;
                                }
                                // cache maybe not available
                                catch(e) {
                                    owner._log("in controller","error",e);
                                    sleep(5000); // done do avoid fast spinning in case of an error TODO move to config
                                }
                            }
                            owner.startTasks(engine,el,instances,listeners,globalSwitch,activator,prefix);
                        }
                        first=false;
                    }
                    // look for changes
                    else if(lastCheck+checkForChangeInterval<getTickCount()) {
                        var cfcs=loadCFCs(cfcs);
                        owner.replaceit(tasks,filter(cfcs,"task"));
                        var listeners=filter(cfcs,"listener",listeners);

                        // stop modidified and deleted
                        loop struct=tasks index="local.cfcName" item="local.el" {
                            // take them out of the loop
                            if(el.status=="deleted" || el.status=="modified") {
                                loop struct=instances index="local.instanceHash" item="local.instance" {
                                    if(instance.task.name==cfcName) {
                                        instance.enabled=false; 
                                        structDelete(instances, instanceHash,false);
                                        owner._log("removes task instance [#el.name#:#instance.index#]");
                                    }
                                }
                                if(el.status=="deleted") {
                                    structDelete(tasks, cfcName,false);
                                    owner._log("deletes task [#el.name#]");
                                }
                            }
                        }


                        // do we have instances not running that should?
                        loop struct=instances index="local.instanceHash" item="local.instance" {
                            if(instance.stopped?:false) {
                                instance.enabled=false; 
                                structDelete(instances, instanceHash,false);
                                instance.task.status="failed";
                                if(!(instance.task.paused?:false)){
                                    owner._log("instance failed for an unknown reason and will be removed from pool, task instance [#el.name#:#instance.index#]","error");
                                }
                            }
                        }

                        // start new and modified tasks
                        loop struct=tasks index="cfcName" item="local.el" {
                            if((el.status=="new" || el.status=="modified" || el.status=="failed")) {
                                owner.startTasks(engine,el,instances,listeners,globalSwitch,activator,prefix);
                                owner._log("starts task instance(s) [#el.name#]");
                                el.status="existing";
                            }
                        }
                        lastCheck=getTickCount();
                    }


                    // do have other servers changed the pause settings?
                    if(!isEmpty(settingLocation) && variables.checkForChangeSettingInterval>0 && lastCheckSettings+variables.checkForChangeSettingInterval<getTickCount()) {
                        var threadName="t#createUniqueID()#";
                        thread name=threadName gatewayId=(gatewayId?:"") owner=owner tasks=tasks settingLocation=settingLocation {
                            try {
                                loop struct=tasks index="cfcName" item="local.el" {
                                    var paused=owner.getPause(settingLocation, gatewayId, (el.id?:""));
                                    if((paused?:false)!=(el.paused?:false)) el.paused=paused?:false;
                                }
                            }
                            // cache maybe not available
                            catch(e) {
                                owner._log("in controller","error",e);
                            }
                        }
                        // because we don't need the thread reference we simply remove it
                        structDelete(cfthread, threadName, false);
                        lastCheckSettings=getTickCount();
                    }
                }
                catch(e) {
                    owner._log("in controller","error",e);
                    sleep(5000); // done do avoid fast spinning in case of an error TODO move to config
                }
                sleep(variables.controllerInterval); // TODO use notify in addition to end it
            }
            // wait for the tasks to end
            var start=getTickCount();
            var max=1200;
            try {
                owner._log("checking for running task instance(s) to stop (#len(instances)#)","debug");
                while(--max>0) {

                    // get all active task names
                    var taskNames=structKeyArray(instances);
                    if(len(taskNames)==0)break;
                    loop array=taskNames item="local.name" {

                        // possible it is already gone in meantime
                        var instance=instances[name]?:"";
                        if(isSimpleValue(instance)) {
                            owner._log("did stop on it's own [#instance.task.name#:#instance.index?:"<none>"#]");
                            continue;
                        }
                        // grace period is over
                        if(instance.task.waitForStop+start<getTickCount()) {
                            owner._log("reached grace period for task [#instance.task.name#]");
                            if(instance.task.forceStop) {
                                try {
                                    owner._log("forces termination of task instance [#instance.task.name#:#instance.index?:"<none>"#]");
                                    thread action="terminate" name=name;
                                }
                                catch(e) {
                                    // TODO it seem not to stop even it still exists
                                }
                            }
                            structDelete(instances,name,false);
                        }
                    }
                    sleep(100);
                }
                owner._log("has stopped all task instances");
                                    
            }
            catch(e) {
                owner._log("failed to finalize the controller");
            }
            finally {
                owner.setState("stopped");
            }
        }

	}

    public function startTasks(engine,task, instances,listeners,globalSwitch,activator,prefix) {
        loop from=1 to=task.threads item="local.index" {
            var instanceName=hash(prefix&":"&task.name&":"&index&":"&createUniqueID(),"quick");
            var instance={'name':instanceName,'index':index,'task':task,'startDate':now(),'iterations':0,'errors':0,'enabled':true};
            instances[instanceName]=instance;
            try{inspectTemplates();}catch(e) {pagePoolClear();} // older Lucee version do not support inspectTemplates...
            // create the instance itself
            try{
                _log("instantiate task [#instance.task.name#:#instance.index#]");
                if(!isNull(task.properties)) {
                    instance.cfc=new TaskForScheduler(task.name,task.properties);
                }
                else instance.cfc=new "#task.name#"();
            }
            catch(e) {
                _log("failed to construct [#instance.task.name#]","error",e);
            }

            thread name=instanceName owner=this engine=engine globalSwitch=globalSwitch activator=activator listeners=listeners instance=instance instances=instances {
                owner._log("start task instance [#instance.task.name#:#instance.index#]");
                try {
                    while(instance.enabled && !(instance.task.paused?:false) && globalSwitch.enabled && engine.isRunning() && activator.active()) {
                        setting requesttimeout="100000000000";// 3170 years
                        try {
                            // sleep before
                            if(instance.task.sleepBefore>0) sleep(instance.task.sleepBefore);
                            
                            // stopped in meantime?
                            if((!instance.enabled || (instance.task.paused?:false) || !globalSwitch.enabled || !engine.isRunning() || !activator.active())) break;

                            // execute
                            var startDate=now();
                            var startTime=getTickCount();
                            var newInstance=false;
                            // listener before
                            if(len(listeners)) {
                                try {
                                    loop struct=listeners index="local.name" item="local.listener" {
                                        if(allowed(instance.task.name,listener.allowed,listener.denied)) {
                                            try {
                                                listener.instance.onExecutionStart(instance.cfc,instance.task.name,instance.name,instance.iterations,instance.errors,instance.lastExecutionTime?:nullValue(),instance.lastExecutionDate?:nullValue(),instance.lastError?:nullValue());
                                            } 
                                            catch(ee){
                                                owner._log("failed to execute listener instance","error",ee);
                                            }
                                        }
                                    }
                                } 
                                catch(e){
                                    owner._log("failed to execute listener instance","error",e);
                                }
                            }
                            instance.cfc.invoke(instance.name,instance.iterations,instance.errors,instance.lastExecutionTime?:nullValue(),instance.lastExecutionDate?:nullValue(),instance.lastError?:nullValue());
                            owner._log("executes task instance [#instance.task.name#:#instance.index#] sucessfully","debug");
                            
                            // listener after
                            if(len(listeners)) {
                                try {
                                    loop struct=listeners index="local.name" item="local.listener" {
                                        if(allowed(instance.task.name,listener.allowed,listener.denied)) {
                                            try {
                                                listener.instance.onExecutionEnd(instance.cfc,instance.task.name,instance.name,instance.iterations,instance.errors,instance.lastExecutionTime?:nullValue(),instance.lastExecutionDate?:nullValue(),instance.lastError?:nullValue());
                                            } 
                                            catch(ee){
                                                owner._log("failed to execute listener instance","error",ee);
                                            }
                                        }
                                    }
                                } 
                                catch(e){
                                    owner._log("failed to execute listener instance","error",e);
                                }
                            }
                            instance.lastExecutionTime=getTickCount()-startTime;
                            instance.iterations++;
                            instance.lastExecutionDate=startDate;

                            // sleep after TODO notify when stop
                            if(instance.task.sleepAfter>0 && (instance.enabled && globalSwitch.enabled && engine.isRunning() && activator.active())) sleep(instance.task.sleepAfter);
                        }
                        catch(e) {
                            instance.errors++;
                            instance.lastError=e;
                            
                            if(len(listeners)) {
                                try {
                                    loop struct=listeners index="local.name" item="local.listener" {
                                        if(allowed(instance.task.name,listener.allowed,listener.denied)) {
                                            try {
                                                listener.instance.onError(e,instance.cfc,instance.task.name,instance.name,instance.iterations,instance.errors,instance.lastExecutionTime?:nullValue(),instance.lastExecutionDate?:nullValue(),instance.lastError?:nullValue());
                                            } 
                                            catch(eee){
                                                owner._log("failed to execute listener instance","error",eee);
                                            }
                                        }
                                    }
                                } 
                                catch(ee){
                                    owner._log("failed to execute listener instance","error",ee);
                                }
                            }

                            owner._log("failed to execute task instance [#instance.task.name#]; start:#instance.startDate#; iterations:#instance.iterations#; errors: #instance.errors#; last-exe:#instance.lastExecutionDate?:""# ","error",e);
                            
                            // sleep after error TODO notify when stop
                            if(instance.task.sleepAfterOnError>0 && (instance.enabled && globalSwitch.enabled && engine.isRunning() && activator.active())) sleep(instance.task.sleepAfterOnError);
                            //structDelete(instance, "cfc",false); // remove that instance so a new one is created
                        }
                        finally {
                            try {
                                var pc=getPageContext();
                                var writer=pc.getOut();
                                writer.clearBuffer(); // clears data in response buffer
                            }
                            catch(ex) {}
                        }
                    }
                }
                finally {
                    // do we end even we should not, because of cfabort for example 
                    if(engine.isRunning() && globalSwitch.enabled && instance.enabled  && activator.active()) {
                        owner._log("stops task instance [#instance.task.name#:#instance.index#]; engine-switch:#engine.isRunning()#; global-switch:#globalSwitch.enabled#;task-switch:#(instance.task.paused?:false)#;instance-switch:#instance.enabled#;activator:#activator.active()#;");
                        instance.stopped=true;
                    }
                    else structDelete(instances, instance.name,false);
                    
                    owner._log("stops task instance [#instance.task.name#:#instance.index#]; engine-switch:#engine.isRunning()#; global-switch:#globalSwitch.enabled#;task-switch:#(instance.task.paused?:false)#;instance-switch:#instance.enabled#;activator:#activator.active()#;");
                }
            }
        }
    }

    public function loadCFCs(existing) {
        var inital=isNull(existing);
        _log("#inital?"loads all the tasks":"check if the task have changed"#");
        
        var data={};
        var rawDatas=[];
        try{
            loop array=ComponentListPackage(variables.package) item="local.cfcName" {
                arrayAppend(rawDatas, cfcName);
            }
        }
        catch(e) {// throws an error if there are no tasks
        }

         // load from templates
        try {
            if(!isNull(variables.templatePath) && !isEmpty(variables.templatePath)) {
                local.path=variables.templatePath;
                if(!directoryExists(path)) {
                    local.path=expandPath(path);
                }

                if(directoryExists(path)) {
                    loop array=readTemplates(path,variables.checkForChangeInterval,variables.checkForChangeNoMatchInterval,variables.templatePathRecursive) item="local.templateData" {
                        arrayAppend(rawDatas, templateData);
                    }
                }
            }
        }
        catch(e) {}
   
        loop array=rawDatas item="local.rawData" {
            try {
                // when simple value it is a component name otherwise template info
                var fullName=isSimpleValue(rawData)?(variables.package&"."&rawData):rawData.template;
                if(!inital) {
                    if(structKeyExists(existing, fullName)){
                        var ex=existing[fullName].lastModified;
                        var atm=fileInfo(existing[fullName].path).dateLastModified;
                        
                        // file has not changed
                        if(ex.getTime()==atm.getTime()) {
                            _log("could not detected a change in component [#fullName#]","debug");
                            var el=duplicate(existing[fullName]);
                            el.status="new";
                            data[el.name]=el;
                            continue;
                        }
                    }
                }
            
                _log("loads a new component/template [#fullName#]");
                var el={};
                el.status="new";
                el.name=fullName;
                el.id=hash(fullName,"quick");
                try {
                    inspectTemplates();}catch(e) {pagePoolClear();} // older Lucee version do not support inspectTemplates...
                    if(isSimpleValue(rawData)) {
                        el.meta=getComponentMetadata(el.name);
                        if(el.meta.abstract?:false) {
                            // we do this so this component get not get checked all the time 
                            el.type="other";
                            continue;
                        }
                        local.cfc=createObject("component",el.name); // we do here not new to avoid the init method
                    }
                    else {
                        local.cfc=new TaskForScheduler(el.name,rawData.properties);
                        el.properties=rawData.properties;
                    }
                    
                    if(isNull(el.meta)) {
                        el.meta=getMetadata(cfc);
                    }
                    
                    // it is allowed to have none task/listener in the package, but they simply get ignored
                    
                    if(IsInstanceOf(cfc, "org.lucee.cfml.Task")) {
                        el.type="task";
                    }
                    else if(IsInstanceOf(cfc, "org.lucee.cfml.Listener")) {
                        el.type="listener";
                        el.instance=new "#el.name#"();
                    }
                    else {
                        // we do this so this component get not get checked all the time 
                        el.type="other";
                        continue;
                    }

                    // file info
                    el.template=fullname;
                    el.path=isSimpleValue(rawData)?el.meta.path:fullname;
                    el.fileInfo=fileInfo(el.path);
                    el.lastModified=el.fileInfo.dateLastModified;

                    if(el.type=="task") {
                        // sleep before
                        el.sleepBefore=cfc.getHowLongToSleepBeforeTheCall();
                        if(!isNumeric(el.sleepBefore) || el.sleepBefore<0)el.sleepBefore=0;

                        // sleep after
                        el.sleepAfter=cfc.getHowLongToSleepAfterTheCall();
                        if(!isNumeric(el.sleepAfter) || el.sleepAfter<0)el.sleepAfter=0;

                        // sleep after on error
                        el.sleepAfterOnError=cfc.getHowLongToSleepAfterTheCallWhenError();
                        if(!isNumeric(el.sleepAfterOnError) || el.sleepAfterOnError<0)el.sleepAfterOnError=0;

                        // threads
                        el.threads=cfc.getConcurrentThreadCount();
                        if(!isNumeric(el.threads) || el.threads<0)el.threads=0;

                        // wait for stop
                        el.waitForStop=int(cfc.getHowLongToWaitForTaskOnStop());
                        if(!isNumeric(el.waitForStop) || el.waitForStop<0)el.waitForStop=0;
                        
                        // force stop
                        el.forceStop=cfc.getForceStop();
                        if(!isBoolean(el.forceStop))el.forceStop=0;
                    }
                    else if(el.type=="listener") {
                        // allowed
                        el.allowedRaw=cfc.getAllow();
                        if(isNull(el.allowedRaw)) el.allowedRaw="*";
                        el.allowed=convertWildcardToRegex(el.allowedRaw);
                        
                        // denied
                        el.deniedRaw=cfc.getDeny();
                        if(isNull(el.deniedRaw)) el.deniedRaw="";
                        el.denied=convertWildcardToRegex(el.deniedRaw);
                    }
                    // add to array
                    data[el.name]=el;
                }
            catch(e) {
                _log("failed to load task or listener","error",e);
            }
        }
        // inital call
        if(inital) {
            _log("has #len(data)# task(s) loaded","debug");
            return data;
        }
        // set existing, deleted, modified
        loop struct=existing index="local.cfcName" item="local.el" {
            el.status="existing";
            if(!structKeyExists(data,cfcName)) {
                if(el.type=="listener") structDelete(existing, cfcName);
                else el.status="deleted";
                _log("marked task [#el.name#] as deleted","debug");
            }
            else if (el.lastModified!=data[cfcName].lastModified) {
                existing[cfcName]=data[cfcName];
                existing[cfcName].status="modified";
                _log("marked task [#el.name#] as modified","debug");
            }
        }

        // set new
        loop struct=data index="local.cfcName" item="local.el" {
            if(!structKeyExists(existing,cfcName)) {
                existing[cfcName]=el;
                _log("has detected a new task with name [#el.name#]","debug");
            }
        }
        return existing;
    }

    public function getEngine() {
		var pc=getPageContext();
		var config=pc.getConfig();
		var factory=config.getFactory();
		return factory.getEngine();
	}

    private function filter(cfcs, type, existing="") {
        // we do this because other code has a reference to this struct
        if(isStruct(existing)) {
            structClear(existing);
            filtered=existing
        }
        else local.filtered={};
        loop struct=cfcs index="local.k" item="local.v" {
            if(type==v.type) filtered[k]=v;
        }
        return filtered;
    }

    private function convertWildcardToRegex(required string listTasks) {
        if(isEmpty(listTasks)) return [];

        var arr=listToArray(listTasks);
        var rtn=[];
        for(var i=len(arr);i>0;i--) {
            var str=trim(arr[i]);
            if(isEmpty(str)) continue;

            str=replace(str,".","\.","all");
            str=replace(str,"*","[[:alnum:]]*","all");
            str=replace(str,"?","[[:alnum:]]","all");
            arrayAppend(rtn,str);
        }
        return rtn;
    }

    private function allowed(taskName, array allowed=["*"], array denied=[]) cachedwithin=0.1 {
        var name=listLast(taskName,".");
        // allowed ?
        var isAllowed=false;
        loop array=allowed item="local.regex" {
            if(reFindNoCase(regex,taskName) || reFindNoCase(regex,name)) {
                isAllowed=true;
                break;
            }
        }
        if(!isAllowed) return false;
        
        // denied?
        loop array=denied item="local.regex" {
            if(reFindNoCase(regex,taskName) || reFindNoCase(regex,name)) {
                return false;
            }
        }
        return true;
    }

    /**
     * reads the metadata from cfml templates
     * @path path to the folder containg the templates
     * @checkForChangeInterval how long to cache a result, in case the previous check did get a result
     * @checkForChangeNoMatchInterval how long to cache a result, in case the previous check did NOT get a result
     */
    private function readTemplates(required string path, number checkForChangInterval, number checkForChangeNoMatchInterval, boolean templatePathRecursive=true) {
        var results=[];
        var now=now();
        var files=directoryList(path:path,recurse:arguments.templatePathRecursive,filter:function(path) {
            if(right(arguments.path,4)!=".cfm") return false;
            if(!isNull(variables.templateCache[path])) {
                var result=variables.templateCache[path];
                if(!isNull(result.data)) {
                    if(dateDiff("l", result.lastRead, now)<checkForChangInterval) {
                        arrayAppend(results, {"properties":result.data,"template":path});
                        return true;  
                    }
                }
                else {
                    if(dateDiff("l", result.lastRead, now)<checkForChangeNoMatchInterval) {
                        return false;  
                    }  
                }
            }
            var content=fileRead(path);
            // filter  comments
            var startIndex=0;
            var endIndex=0;
            var count=100;
            var result="";
            while((startIndex=find("<!---", content,endIndex))!=0) {
                if(count--==0)break;
                endIndex=find("--->", content,startIndex+5);
                var c=mid(content, startIndex+5, endIndex-startIndex-5);
               
                if(!findNoCase("@", c)) continue;
                var arr=listToArray(c,NL); 
                loop array=arr item="local.item" {
                    item=item.trim();

                    if(!len(item) || item[1]!="@") continue;
                    var i1=find(" ", item);
                    var i2=find("   ", item);
                    if(i1==0 && i2==0)  continue;
                    else if(i1==0)  local.i=i2;
                    else if(i2==0)  local.i=i1;
                    else local.i=min(i1, i2);
                    
                    var name=mid(item, 2, i-2);
                    var value=trim(mid(item, i));
                    if((left(value,1)=="'" && right(value,1)=="'") || (left(value,1)=="""" && right(value,1)=="""")) {
                        value=trim(mid(value,2,len(value)-2));
                    }
                    if(isSimpleValue(result)) result={};
                    result[name]=value;
                }
            }
            if(!isSimpleValue(result)) {
                variables.templateCache[path]={"data":result,"lastRead":now()};
                arrayAppend(results, {"properties":result,"template":path})
                return true;
            }
            variables.templateCache[path]={"lastRead":now()};
            return false;
        });
            
        return results;
    }

    private function readSystemPropOrEnvVar(key, defaultValue) {
        var res=server.system.environment[key]?:nullValue();
        if(!isNull(res)) return res;
        var res=server.system.properties[key]?:nullValue();
        if(!isNull(res)) return res;
        var res=server.system.environment[ucase(replace(key, ".", "_","all"))]?:nullValue();
        if(!isNull(res)) return res;
        return defaultValue;
    }

    public function replaceit(existingData, newData) {
        structClear(existingData);
        loop struct=newData index="local.k" item="local.v" {
            existingData[k]=v;
        }
    }

    function _log(required string msg, string level="info", exception) {
        
        try {
            if(isNull(exception)) {
                log text="Tasks Event Gateway: "&arguments.msg type=arguments.level log=variables.logName;
            }
            else {
                log text="Tasks Event Gateway: "&arguments.msg type=arguments.level exception=exception log=variables.logName;
            }
        }
        catch(ex) {
            systemOutput(arguments,1,1);
            systemOutput(ex,1,1);
        }
    }
}