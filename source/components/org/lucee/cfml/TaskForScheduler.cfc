component extends="org.lucee.cfml.Task" persistent=true {

	property name="concurrentThreadCount" type="numeric" default=1;
	property name="howLongToSleepBeforeTheCall" type="numeric" default=0;
	property name="howLongToSleepAfterTheCall" type="numeric" default=0;
	property name="howLongToSleepAfterTheCallWhenError" type="numeric" default=60000;
	property name="howLongToWaitForTaskOnStop" type="numeric" default=10000;
	property name="forceStop" type="boolean" default=false;

	public string function getLabel() {
		return variables.label;
	}

	public void function init(required string path,required struct props) {
		variables.path=arguments.path;
		// write the properties to the variables scope
		loop struct=arguments.props index="local.k" item="local.v" {
			variables[k]=v;
		}

		if(structKeyExists(variables, "task")) variables.label=variables.task;
		else if(structKeyExists(variables, "name")) variables.label=variables.name;
		else {
			variables.label=listLast(arguments.path,"\/");
		}

	}

	public void function invoke(required string id,required numeric iterations, required numeric errors, 
		numeric lastExecutionTime, date lastExecutionDate, struct lastError) {
		local.urls={};
		loop struct=arguments index="local.k" item="local.v" {
			urls[k]=v?:nullValue();
		}
		_internalRequest(template:contractPath(path),urls:urls);
	}
}