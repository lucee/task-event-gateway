abstract component persistent=true {

	/**
	* this can contain a comma separated list of Task that are ALLOWED like "MyTask,YourTask".
	* So the listener will listen to this Tasks. 
	* You can also include package names (like "org.lucee.cfml.MyTask") but not file extensions (like "MyTask.cfc").
	* In addition the task names can contain wildcards like "?" as a placeholder for one character (a-z,A-z,0-9) and "*" as a placeholder for 
	* 0 to n characters (a-z,A-z,0-9) like "*Task" or "My?ask".
	*/
	property name="allow" type="string" default="*";

	/**
	* this can contain a comma separated list of Task that are DENIED like "MyTask,YourTask".
	* So the listener will NOT listen to this Tasks. 
	* You can also include package names (like "org.lucee.cfml.MyTask") but not file extensions (like "MyTask.cfc").
	* in addition the task names can contain wildcards like "?" as a placeholder for one character (a-z,A-z,0-9) and "*" as a placeholder for 
	* 0 to n characters (a-z,A-z,0-9) like "*Task" or "My?ask".
	*
	* This property will overrules the allow property, means if a task is defined here and in the "allow" property, it will be denied.
	*/
	property name="deny" type="string" default="";

	/**
	* listener invoked in case a task is throwing an error
	*/
	public abstract void function onError(struct error,component instance, string task, required string id,required numeric iterations, required numeric errors, numeric lastExecutionTime, date lastExecutionDate, struct lastError);

	/**
	* listener invoked before the execution of the task
	*/
	public abstract void function onExecutionStart(component instance, string task, required string id,required numeric iterations, required numeric errors, numeric lastExecutionTime, date lastExecutionDate, struct lastError);

	/**
	* listener invoked after the execution of the task
	*/
	public abstract void function onExecutionEnd(component instance, string task, required string id,required numeric iterations, required numeric errors, numeric lastExecutionTime, date lastExecutionDate, struct lastError);
}