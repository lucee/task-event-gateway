Tasks Event Gateway (TEG)
==================================
This extension adds the ability to run self configured Tasks when installed into Lucee Server.

## Build
The extension is a ANT project, in order to build it, you need to have ANT installed on your machine.
When ANT is available then simply call 
```
ant
``` 
within the project root. Then a new folder "target" will be created that contains the newly build extension.

## Installation
To install the extension, simply copy the generated .lex file to the "/lucee-server/deploy" folder of your Lucee installation.

## Configuration
The configuration of the TEG is done in 2 places. In the build.xml for global settings and in every Task/Listener implementation for Task/Listener specific settings.

### Gloabl configuration
In the `build.xml` on around line 36 to 45, the `META-INF/MANIFEST.MF` file for the Extension gets written with a defintion for a specific event gateway instance that looks like this:
```
{'cfc-path':'org.lucee.cfml.TasksGateway','id':'lucee-task','read-only':true,'startup-mode':'automatic','custom':{'package':"core.tasks",'templatePath':"/cron",'checkForChangeInterval':10,'checkForChangeNoMatchInterval':60,logName':"scheduler"}}
```
Most important settings for us we may need to touch is `checkForChangeInterval`, this defines the interval that the TEG checks for code changes with in the tasks files. With a higher setting we reduce the amount of file interaction, but of course, it then takes longer for a code change to get detected and applied.
The settings `checkForChangeNoMatchInterval`, defines the interval for none Tasks, that means when a template was not detected as a Task in the previous check, normally the interval set for this is higher.

Another setting we may consider to change is `logName`, this defines where the extension will log it's actions. 
The extension uses 4 different log levels

* __debug__ - logging done while regular excecution of tasks
* __info__ - logging done when changes happening, like a task, get removed,modified or added.
* __warn__ - when a task fail to execute
* __error__ - when the TGE itself has an unexpected exception

#### Configuration via Enviroment Variables or System Property
A global configuration also can be done via Enviroment Variables or System Property. The configuration done in the build.xml (see above) always overwrites this configuration. The following settings are possible, the list always shows the enviroment variable followed by the system property key for the same value

* TASKS_EVENT_GATEWAY_PACKAGE / tasks.event.gateway.package - set the package used to search components (default="org.lucee.cfml.tasks")
* TASKS_EVENT_GATEWAY_TEMPLATE_PATH / tasks.event.gateway.template.path - set the directory path for .cfm based templates (default="")
* TASKS_EVENT_GATEWAY_TEMPLATE_PATH_RECURSIVE / tasks.event.gateway.template.path.recursive - look into sub directories for tasks or not (default=true)
* TASKS_EVENT_GATEWAY_CHECKFORCHANGEINTERVAL / tasks.event.gateway.checkForChangeInterval - time in seconds to check for change when previously the template was detected as a task (default=10)
* TASKS_EVENT_GATEWAY_CHECKFORCHANGENOMATCHINTERVAL / tasks.event.gateway.checkForChangeNoMatchInterval - time in seconds to check for change when previously the template was NOT detected as a task (default=60)
* TASKS_EVENT_GATEWAY_LOG / tasks.event.gateway.log - name of the log used (default="application")

### Task configuration
Task get configured by the task itself, by setting property settings that looks like this
```
	property name="concurrentThreadCount" type="numeric" default=1;
	property name="howLongToSleepBeforeTheCall" type="numeric" default=1000;
	property name="howLongToSleepAfterTheCall" type="numeric" default=1000;
	property name="howLongToSleepAfterTheCallWhenError" type="numeric" default=10000;
	property name="howLongToWaitForTaskOnStop" type="numeric" default=10000;
	property name="forceStop" type="boolean" default=true;
```
What every specific property mean and does is documented in the Task compononent that can be found here
/source/components/org/lucee/cfml/Task.cfc

Just one setting we want to mention here, because i think it is very important:
`howLongToSleepAfterTheCallWhenError` :This setting defines how long a task pauses after an exception happens, this is important to avoid the task to  start to spin in case of an error.
Normally we wany slow down a task in case of an error happening and not speed up!

### Listener configuration
Listener get configured by the listener itself, by setting property settings that looks like this
```
	property name="allow" type="string" default="*";
	property name="deny" type="string" default="";
```
This properties define for which Task this listener is used. More details for how to configure them can be found here
/source/components/org/lucee/cfml/Listener.cfc



## Create your own task runner
The `build.xml` defines where the TEG is looking for Tasks, in your example above in the "Gloabl configuration" section, this is set to:
```
'package':"core.tasks"
```
That means that the TEG is looking for a component package with the name "core.task" (which would map to /core/tasks) and in that directory (if found) the TEG looks for components that extend the "org.lucee.cfml.Task" component that gets installed by the extension.

So to create a runner,  simply create a component that extends `org.lucee.cfm.Task` and implements the abstract functions, for example:
```
component extends="org.lucee.cfml.Task" {
	property name="concurrentThreadCount" type="numeric" default=1;
	property name="howLongToSleepBeforeTheCall" type="numeric" default=1000;
	property name="howLongToSleepAfterTheCall" type="numeric" default=1000;
	property name="howLongToSleepAfterTheCallWhenError" type="numeric" default=10000;
	property name="howLongToWaitForTaskOnStop" type="numeric" default=10000;
	property name="forceStop" type="boolean" default=true;

	public function init() {
		systemOutput("----- INIT -----",1,1);
	}

	public void function invoke(required string id,required numeric iterations, required numeric errors, numeric lastExecutionTime, date lastExecutionDate, struct lastError) {
		// write some data recevied by TEG to the console
		systemOutput("---- #id# it:#iterations# err:#errors# last:#lastExecutionDate?:"<none>"# last-time:#lastExecutionTime?:"<none>"# #now()# -----",1,1);
		// sleep to simulate some work to be done
		sleep(randRange(1000,5000)); 
	}
}
```
All the properties come with default values from the abstract component and because of that they are all optional.

## .cfm based Tasks
A Task can also be defined as a simple .cfm Template, this should mostly be used to reuse existing scheduled tasks without a need to rewrite them.
This tasks get executed as a internal request, that means that also the Application.cfc get executed in advance.

For this the following configuration is necessary
```
'templatePath':"/cron"
```
This can be an absolute directory path, a mapping or a path relative to the webroot. The TEG then will look for changes in all the .cfm templates in that directory, as a minimal requirement to be executed,they need the following metadata in the beginning of the file:
```
<!---
@task "CFML Dummy Task"
@description "This CFML Dummy Task is just to show the functionality"
@concurrentThreadCount 1
@howLongToSleepBeforeTheCall 2000
@howLongToSleepAfterTheCall 2000
@howLongToSleepAfterTheCallWhenError 10000
@howLongToWaitForTaskOnStop 10000
@forceStop 10000
--->
```
This are exactly the same settings and rules, as with the component based tasks.

You get provided the same arguments you have with the arguments scope for components in the url scope.
This includes the following Arguments:

* url.id
* url.iterations
* url.errors
* url.lastExecutionTime
* url.lastExecutionDate
* url.lastError


## Create your own listener
Listener get defined exactly the same way as Tasks (see section above), they simply have to implement a different interface, that's it.

So to create a listener, simply create a component that extends `org.lucee.cfm.Listener` and implements the abstract functions, for example:
```
component extends="org.lucee.cfml.Listener" {

	property name="allow" type="numeric" default="*";
	property name="deny" type="numeric" default="";

	public void function onError(struct error,component instance, string task, required string id,required numeric iterations, required numeric errors, numeric lastExecutionTime, date lastExecutionDate, struct lastError) {
		systemOutput("----- MyListener.onError -----",1,1);
		systemOutput(error.message,1,1);
	}

	public void function onExecutionStart(component instance, string task, required string id,required numeric iterations, required numeric errors, numeric lastExecutionTime, date lastExecutionDate, struct lastError) {
		systemOutput("----- MyListener.onExecutionStart -----",1,1);
		if(!isNull(lastError))lastError=lastError.message; // otherwise we blow up the console
		systemOutput(arguments,1,1);
	}

	public void function onExecutionEnd(component instance, string task, required string id,required numeric iterations, required numeric errors, numeric lastExecutionTime, date lastExecutionDate, struct lastError) {
		systemOutput("----- MyListener.onExecutionEnd -----",1,1);
		if(!isNull(lastError))lastError=lastError.message; // otherwise we blow up the console
		systemOutput(arguments,1,1);
	}
}
```
All the properties come with default values from the abstract component and because of that they are all optional.
