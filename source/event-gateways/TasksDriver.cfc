component extends="Gateway" {


    fields = array(

        field( "Package name", "package", "org.lucee.cfml.tasks", true, 
            "Name of the package (folder) where the Task component are located. Task comonent must estend the component ""org.lucee.cfml.Task"" ", "text" ) 
        , field( "Template path", "templatePath", "", true, 
            "Path to a folder that contains templates to execute, the templates must contain metadata (read more in the documentation 
            for tempate path), the template must be within the webroot or in a exposed mapping, 
            so they can be executed with a InternalRequest call. 
            Main purpose of this is to execute old scheduled tasks, without having them to change to much.", "text" ) 
        , field( "Check for changes", "checkForChangeInterval", 10, false, 
            "Time interval for the Event Gateway to check for updates on the Tasks.", "time" )
        , field( "Check for changes no match before", "checkForChangeNoMatchInterval", 60, false, 
            "Time interval for the Event Gateway to check for updates on the Tasks that before was no task. So a component not implementing the necessary interface or a template missing the necessary meta data.", "time" )
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