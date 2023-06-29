component {
	variables.logName="application";
	variables._state="stopped";
    variables.controllerInterval=1000;// interval in ms of the controller thread
    variables.stopInterval=10;
    variables.checkForChangeInterval=10000;
    variables.NL="
";
	public void function init(string id, struct config, component listener) { 
        variables.id=arguments.id;
        try {
            log text="Tasks Event Gateway init" type="info" log=logName;
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
            
            // log
            variables.logName=config.logName?:"";
            if(isEmpty(trim(variables.logName)))variables.logName=readSystemPropOrEnvVar("tasks.event.gateway.log", "application");

            log text="Tasks Event Gateway init config: "&serialize(config) type="info" log=logName;
        }
        catch(e){
            // systemOutput(e,1,1);
			log text="Tasks Event Gateway failed in init function" exception="#e#" type="error" log=logName;
        }
		
	}

	public void function start() {
        try {
			log text="Tasks Event Gateway starting" type="info" log=logName;
            // just in case Start get triggered without stop before
            if(!isNull(variables.globalSwitch) && variables.globalSwitch.enabled)
                variables.globalSwitch.enabled=false;

			variables.globalSwitch={enabled:true};
            variables._state="starting";
            run(variables.globalSwitch);
            // wait for the runner to start up (that should only take couple ms)
            var countDown=500;
            while(--countDown>0) {
                if(getState()=="running") break;
                sleep(5);
            }
            if(getState()=="running")
                log text="Tasks Event Gateway sucessfully started" type="info" log=logName;
            else
                log text="Tasks Event Gateway failed to start for unknown reasons" type="error" log=logName;
        }
        catch(local.e){
			variables._state="failed";
			log text="Tasks Event Gateway failed in start function" exception=e type="error" log=logName;
        }
	}

	public void function stop() {
        log text="Tasks Event Gateway stopping" type="info" log=logName;
        if(getState()!="running") {
            log text="Tasks Event Gateway could not stop, state was not running" type="error" log=logName;
            return;
        }
        // TODO notify controller
		try {
			variables._state="stopping";
            variables.globalSwitch.enabled=false;
			
            // wait for the runner to stop by itself
            log text="Tasks Event Gateway stopping: check for stopped" type="debug" log=logName;
            var countDown=600;
            while(--countDown>0) {
                if(getState()=="stopped") break;
                sleep(100);
            }
            
            setState("stopped");
        }
        catch(local.e){
			variables._state="failed";
			log text="Tasks Event Gateway failed in stop function" exception="#e#" type="error" log=logName;
        }
	}


	public void function restart() {
        log text="Tasks Event Gateway restarting" type="info" log=logName;
			
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
        var tasks= getTasks();
        var task=tasks[taskName];
        if(isNull(local.task)) {
            if(len(tasks)) cfthrow(message:"there is no task with name [#arguments.taskName#], we only have the following tasks [#structKeyList(tasks)#]",detail:usage);
            else cfthrow(message:"there is no task with name [#arguments.taskName#], we have no tasks available",detail:usage);
        }
        task.paused=arguments.paused;
        // when we have a setting location the pause is phyisical stored ad will survive a restart of the Task Engine job
        if(!isNull(variables.settingLocation)) {
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
        if(!structKeyExists(variables,"_instances")) return {};
        
        // instances
        // task: cfc,meta,fileInfo,threads,,,,
            
        var tasks={};
        loop struct=variables._instances index="local.id" item="local.instance" {
            if(!structKeyExists(tasks,instance.task.name)) {
                var label=instance.task.properties.task?:"";
                if(isNull(label) || isEmpty(label)) label=ListLast(instance.task.name,"./\");
                task={
                    'name':instance.task.name
                    ,'id':instance.task.id?:instance.task.name
                    ,'label':label
                    ,'description':instance.task.properties.description?:""
                    ,'status':instance.task.status
                    ,'path':instance.task.path
                    ,'lastModified':instance.task.lastModified
                    ,'sleepBefore':instance.task.sleepBefore
                    ,'sleepAfter':instance.task.sleepAfter
                    ,'sleepAfterOnError':instance.task.sleepAfterOnError
                    ,'threads':instance.task.threads?:0
                    ,'waitForStop':instance.task.waitForStop
                    ,'forceStop':instance.task.forceStop
                    ,'paused':instance.task.paused?:false
                    ,'instances':[]
                };
                tasks[instance.task.name]=task;
            }
            else task=tasks[instance.task.name];
            
            // instances
            arrayAppend(task.instances,{
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

    private function getTasks() {
        if(!structKeyExists(variables,"_instances")) return {};
        var tasks={};
        loop struct=variables._instances index="local.id" item="local.instance" {
            if(!structKeyExists(tasks,instance.task.name)) {
                tasks[instance.task.name]=instance.task;
            }
        }
        return tasks;
    }

    private void function run(globalSwitch) {
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
            log text="Tasks Event Gateway failed loading the Tasks" exception=e type="error" log=logName;
        }

        // starting the controller (this task only check for changes with the Tasks defined)
        thread  name=controllerName controllerName=controllerName instances=instances owner=this 
                engine=engine logName=logName cfcs=cfcs tasks=tasks listeners=listeners globalSwitch=globalSwitch
                prefix=prefix gatewayId=variables.id  checkForChangeInterval=variables.checkForChangeInterval  settingLocation=variables.settingLocation 
                checkForChangeSettingInterval=variables.checkForChangeSettingInterval {
            log text="Tasks Event Gateway enter controller" type="info" log=logName;
			
            owner.setState("running");
            var first=true;
            var lastCheck=getTickCount();
            var lastCheckSettings=getTickCount();
            while(globalSwitch.enabled && engine.isRunning()) {

                log text="Tasks Event Gateway running the controller, ATM we have #len(instances)# task instances" type="debug" log=logName;
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
                                    log text="Tasks Event Gateway in controller" exception=e type="error" log=logName;
                                    sleep(5000); // done do avoid fast spinning in case of an error TODO move to config
                                }
                            }
                            owner.startTasks(engine,el,instances,listeners,globalSwitch,prefix);
                        }
                        first=false;
                    }
                    // look for changes
                    else if(lastCheck+variables.checkForChangeInterval<getTickCount()) {
                        var cfcs=loadCFCs(cfcs);
                        var tasks=filter(cfcs,"task");
                        var listeners=filter(cfcs,"listener",listeners);

                        // stop modidified and deleted
                        loop struct=tasks index="local.cfcName" item="local.el" {
                            // take them out of the loop
                            if(el.status=="deleted" || el.status=="modified") {
                                loop struct=instances index="local.instanceHash" item="local.instance" {
                                    if(instance.task.name==cfcName) {
                                        instance.enabled=false; 
                                        structDelete(instances, instanceHash,false);
                                        log text="Tasks Event Gateway removes task instance [#el.name#:#instance.index#]" type="info" log=logName;
                                    }
                                }
                                if(el.status=="deleted") {
                                    structDelete(tasks, cfcName,false);
                                    log text="Tasks Event Gateway deletes task [#el.name#]" type="info" log=logName;
                                }
                            }
                        }


                        // do we have instances not running that should?
                        loop struct=instances index="local.instanceHash" item="local.instance" {
                            if(instance.stopped?:false) {
                                instance.enabled=false; 
                                structDelete(instances, instanceHash,false);
                                instance.task.status="failed";
                                log text="Tasks Event Gateway instance failed for an unknown reason and will be removed from pool, task instance [#el.name#:#instance.index#]" type="error" log=logName;
                            }
                        }

                        // start new and modified tasks
                        loop struct=tasks index="cfcName" item="local.el" {
                            if(el.status=="new" || el.status=="modified" || el.status=="failed") {
                                owner.startTasks(engine,el,instances,listeners,globalSwitch,prefix);
                                log text="Tasks Event Gateway starts task instance(s) [#el.name#]" type="info" log=logName;
                                el.status="existing";
                            }
                        }
                        lastCheck=getTickCount();
                    }


                    // do have other servers changed the pause settings?
                    if(!isEmpty(settingLocation) && variables.checkForChangeSettingInterval>0 && lastCheckSettings+variables.checkForChangeSettingInterval<getTickCount()) {
                        // TODO do we need to flush the cfthread scope after this?
                        thread  gatewayId=(gatewayId?:"") owner=owner tasks=tasks logName=logName settingLocation=settingLocation {
                            try {
                                loop struct=tasks index="cfcName" item="local.el" {
                                    var paused=owner.getPause(settingLocation, gatewayId, (el.id?:""));
                                    if((paused?:false)!=(el.paused?:false)) el.paused=paused?:false;
                                }
                            }
                            // cache maybe not available
                            catch(e) {
                                log text="Tasks Event Gateway in controller" exception=e type="error" log=logName;
                            }
                        }
                        lastCheckSettings=getTickCount();
                    }
                }
                catch(e) {
                    systemOutput(e,1,1);
                    log text="Tasks Event Gateway in controller" exception=e type="error" log=logName;
                    sleep(5000); // done do avoid fast spinning in case of an error TODO move to config
                }
                sleep(variables.controllerInterval); // TODO use notify in addition to end it
            }
            // wait for the tasks to end
            var start=getTickCount();
            var max=1200;
            try {
                log text="Tasks Event Gateway checking for running task instance(s) to stop (#len(instances)#)" type="debug" log=logName;
                while(--max>0) {

                    // get all active task names
                    var taskNames=structKeyArray(instances);
                    if(len(taskNames)==0)break;
                    loop array=taskNames item="local.name" {

                        // possible it is already gone in meantime
                        var instance=instances[name]?:"";
                        if(isSimpleValue(instance)) {
                            log text="Tasks Event Gateway did stop on it's own [#instance.task.name#:#instance.index?:"<none>"#]" type="info" log=logName;
                            continue;
                        }
                        // grace period is over
                        if(instance.task.waitForStop+start<getTickCount()) {
                            log text="Tasks Event Gateway reached grace period for task [#instance.task.name#]" type="info" log=logName;
                            if(instance.task.forceStop) {
                                try {
                                    log text="Tasks Event Gateway forces termination of task instance [#instance.task.name#:#instance.index?:"<none>"#]" type="info" log=logName;
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
                log text="Tasks Event Gateway has stopped all task instances" type="info" log=logName;
                                    
            }
            catch(e) {
                log text="Tasks Event Gateway failed to finalize the controller" exception=e type="error" log=logName;
            }
            finally {
                owner.setState("stopped");
            }
        }

	}

    public function startTasks(engine,task, instances,listeners,globalSwitch,prefix) {
        loop from=1 to=task.threads item="local.index" {
            var instanceName=hash(prefix&":"&task.name&":"&index&":"&createUniqueID(),"quick");
            var instance={'name':instanceName,'index':index,'task':task,'startDate':now(),'iterations':0,'errors':0,'enabled':true};
            instances[instanceName]=instance;
            try{inspectTemplates();}catch(e) {pagePoolClear();} // older Lucee version do not support inspectTemplates...
            // create the instance itself
            try{
                log text="Tasks Event Gateway instantiate task [#instance.task.name#:#instance.index#]" type="info" log=logName;
                if(!isNull(task.properties)) {
                    instance.cfc=new TaskForScheduler(task.name,task.properties);
                }
                else instance.cfc=new "#task.name#"();
            }
            catch(e) {
                log text="Tasks Event Gateway failed to construct [#instance.task.name#]" exception=e type="error" log=logName;
            }

            thread name=instanceName owner=this engine=engine logName=logName globalSwitch=globalSwitch listeners=listeners instance=instance instances=instances {
                log text="Tasks Event Gateway start task instance [#instance.task.name#:#instance.index#]" type="info" log=logName;
                try {
                    while(instance.enabled && globalSwitch.enabled && engine.isRunning()) {
                        setting requesttimeout="100000000000";// 3170 years
                        try{
                            // sleep before
                            if(instance.task.sleepBefore>0) sleep(instance.task.sleepBefore);
                            
                            // stopped in meantime?
                            if((!instance.enabled || !globalSwitch.enabled || !engine.isRunning())) break;

                            // execute
                            var startDate=now();
                            var startTime=getTickCount();
                            var newInstance=false;
                            // listener before
                            if(!(instance.task.paused?:false) && len(listeners)) {
                                try {
                                    loop struct=listeners index="local.name" item="local.listener" {
                                        if(allowed(instance.task.name,listener.allowed,listener.denied)) {
                                            try {
                                                listener.instance.onExecutionStart(instance.cfc,instance.task.name,instance.name,instance.iterations,instance.errors,instance.lastExecutionTime?:nullValue(),instance.lastExecutionDate?:nullValue(),instance.lastError?:nullValue());
                                            } 
                                            catch(ee){
                                                log text="Tasks Event Gateway failed to execute listener instance" exception=ee type="error" log=logName;
                                            }
                                        }
                                    }
                                } 
                                catch(e){
                                    log text="Tasks Event Gateway failed to execute listener instance" exception=e type="error" log=logName;
                                }
                            }
                            if(!(instance.task.paused?:false)) {
                                instance.cfc.invoke(instance.name,instance.iterations,instance.errors,instance.lastExecutionTime?:nullValue(),instance.lastExecutionDate?:nullValue(),instance.lastError?:nullValue());
                                log text="Tasks Event Gateway executes task instance [#instance.task.name#:#instance.index#] sucessfully" type="debug" log=logName;
                            
                            }
                            // listener after
                            if(!(instance.task.paused?:false) && len(listeners)) {
                                try {
                                    loop struct=listeners index="local.name" item="local.listener" {
                                        if(allowed(instance.task.name,listener.allowed,listener.denied)) {
                                            try {
                                                listener.instance.onExecutionEnd(instance.cfc,instance.task.name,instance.name,instance.iterations,instance.errors,instance.lastExecutionTime?:nullValue(),instance.lastExecutionDate?:nullValue(),instance.lastError?:nullValue());
                                            } 
                                            catch(ee){
                                                log text="Tasks Event Gateway failed to execute listener instance" exception=ee type="error" log=logName;
                                            }
                                        }
                                    }
                                } 
                                catch(e){
                                    log text="Tasks Event Gateway failed to execute listener instance" exception=e type="error" log=logName;
                                }
                            }
                            instance.lastExecutionTime=getTickCount()-startTime;
                            instance.iterations++;
                            instance.lastExecutionDate=startDate;

                            // sleep after TODO notify when stop
                            if(instance.task.sleepAfter>0 && (instance.enabled && globalSwitch.enabled && engine.isRunning())) sleep(instance.task.sleepAfter);
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
                                                log text="Tasks Event Gateway failed to execute listener instance" exception=eee type="error" log=logName;
                                            }
                                        }
                                    }
                                } 
                                catch(ee){
                                    log text="Tasks Event Gateway failed to execute listener instance" exception=ee type="error" log=logName;
                                }
                            }

                            log text="Tasks Event Gateway failed to execute task instance [#instance.task.name#]; start:#instance.startDate#; iterations:#instance.iterations#; errors: #instance.errors#; last-exe:#instance.lastExecutionDate?:""# " exception=e type="error" log=logName;

                            // sleep after error TODO notify when stop
                            if(instance.task.sleepAfterOnError>0 && (instance.enabled && globalSwitch.enabled && engine.isRunning())) sleep(instance.task.sleepAfterOnError);
                            //structDelete(instance, "cfc",false); // remove that instance so a new one is created
                        }
                    }
                }
                finally {
                    // do we end even we should not, because of cfabort for example 
                    if(engine.isRunning() && globalSwitch.enabled && instance.enabled) {
                        log text="Tasks Event Gateway stops task instance [#instance.task.name#:#instance.index#]; engine-switch:#engine.isRunning()#; global-switch:#globalSwitch.enabled#;task-switch:#(instance.task.paused?:false)#;instance-switch:#instance.enabled#;" type="info" log=logName;
                        instance.stopped=true;
                    }
                    else structDelete(instances, instance.name,false);
                    
                    log text="Tasks Event Gateway stops task instance [#instance.task.name#:#instance.index#]; engine-switch:#engine.isRunning()#; global-switch:#globalSwitch.enabled#;task-switch:#(instance.task.paused?:false)#;instance-switch:#instance.enabled#;" type="info" log=logName;
                }
            }
        }
    }

    public function loadCFCs(existing) {
        var inital=isNull(existing);
        log text="Tasks Event Gateway #inital?"loads all the tasks":"check if the task have changed"#" type="info" log=logName;
        
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
                            log text="Tasks Event Gateway could not detected a change in component [#fullName#]" type="debug" log=logName;
                            var el=duplicate(existing[fullName]);
                            el.status="new";
                            data[el.name]=el;
                            continue;
                        }
                    }
                }
            
                log text="Tasks Event Gateway loads a new component/template [#fullName#]" type="info" log=logName;
                var el={};
                el.status="new";
                el.name=fullName;
                el.id=hash(fullName,"quick");
                try {
                    inspectTemplates();}catch(e) {pagePoolClear();} // older Lucee version do not support inspectTemplates...
                    local.cfc=isSimpleValue(rawData)?createObject("component",el.name):new TaskForScheduler(el.name,rawData.properties); // we do here not new to avoid the init method
                    if(!isSimpleValue(rawData))el.properties=rawData.properties;
                    el.meta=getMetadata(cfc);
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
                        if(!isNumeric(el.threads) || el.threads<1)el.threads=1;

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
                log text="Tasks Event Gateway failed to load task or listener" exception=e type="error" log=logName;
            }
        }
        // inital call
        if(inital) {
            log text="Tasks Event Gateway has #len(data)# task(s) loaded" type="debug" log=logName;
            return data;
        }
        // set existing, deleted, modified
        loop struct=existing index="local.cfcName" item="local.el" {
            el.status="existing";
            if(!structKeyExists(data,cfcName)) {
                if(el.type=="listener") structDelete(existing, cfcName);
                else el.status="deleted";
                log text="Tasks Event Gateway marked task [#el.name#] as deleted" type="debug" log=logName;
            }
            else if (el.lastModified!=data[cfcName].lastModified) {
                existing[cfcName]=data[cfcName];
                existing[cfcName].status="modified";
                log text="Tasks Event Gateway marked task [#el.name#] as modified" type="debug" log=logName;
            }
        }

        // set new
        loop struct=data index="local.cfcName" item="local.el" {
            if(!structKeyExists(existing,cfcName)) {
                existing[cfcName]=el;
                log text="Tasks Event Gateway has detected a new task with name [#el.name#]" type="debug" log=logName;
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
}