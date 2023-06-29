component extends="Gateway" {


    fields = array(

        field( "Package name", "package", "org.lucee.cfml.tasks", true, 
            "Name of the package (folder) where the Task component are located. Task comonent must extend the component ""org.lucee.cfml.Task"",
            if not defined here, the Task Event Gateway will look for the following enviroment variable as a global setting [TASK_EVENT_GATEWAY_PACKAGE] or the system property [tasks.event.gateway.package], if there is no definition at all the engine will use the package name [org.lucee.cfml.tasks]. ", "text" ) 
        , field( "Template path", "templatePath", "", true, 
            "Path to a folder that contains templates to execute, the templates must contain metadata (read more in the documentation 
            for tempate path), the template must be within the webroot or in a exposed mapping, 
            so they can be executed with a InternalRequest call. 
            Main purpose of this is to execute old scheduled tasks, without having them to change to much.", "text" ) 
        , field( "Check for changes", "checkForChangeInterval", 10, false, 
            "Time interval for the Task Event Gateway to check for updates on already loaded Tasks.", "time" )
        , field( "Check for changes on non Tasks", "checkForChangeNoMatchInterval", 60, false, 
            "Time interval for the Task Event Gateway to check on components/cfml templates that was not defined as a task before. Keep that number high when you have a lot of non task files in the target directory.", "time" )
        , field( "Setting location (Cache)", "settingLocation", "", true, 
        "Location for runtime settings of tasks, ATM this is only used the pause a tasks, this needs to be a cache name of an existing cache, you can point to the same cache from multiple servers and they will share that setting.", "text" ) 
        , field( "Check for changes on settings ", "checkForChangeSettingInterval", 0, false, 
            "When you have defined a setting location and you are using that settings by multiple servers, give here the interval the Task Event Gateway looks for changes made by other servers. This setting is only necessary if multiple servers are using the same setting endpoint. 0 is equal to not checking at all.", "time" )
        , field( "Log name", "logName", "application", true, 
        "Name of the log used to log, this must be an existing log file defined via cfconfig or the Lucee admin.", "text" ) 
    );
    
    public function getLabel() {            return "Tasks" }

    public function getDescription() {      return "A general purpose event gateway which will perform tasks based on components, the Task themself can define the rules for their execution." }

    public function getCfcPath() { 
        pagePoolClear(); // this is a patch for a bug in Lucee, because Lucee follows the regular template cacheg rules for gateways, what is "once" by default.
        return "org.lucee.cfml.TasksGateway"; 
    }


    public function getClass() {            return ""; }

    public function getListenerPath() {     return ""; }


    // public function getListenerCfcMode() {  return "required"; }


    /*/ validate args and throw on failure
    public function onBeforeUpdate( required cfcPath, required startupMode, required custom ) {

        
    }   //*/

}