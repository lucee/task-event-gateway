abstract component persistent=true {

	/**
	* How many concurrent request are maximal allowed for this Task, this must be a number between 1 and n. 
	* The event gateway will open as many concurrent threads as defined here.
	*/
	property name="concurrentThreadCount" type="numeric" default=1;

	/**
	* How long to sleep before the call in milliseconds. This must be a number between 0 and n.
	*/
	property name="howLongToSleepBeforeTheCall" type="numeric" default=0;

	/**
	* How long to sleep after the call in milliseconds. This must be a number between 0 and n.
	*/
	property name="howLongToSleepAfterTheCall" type="numeric" default=0;

	/**
	* How long to sleep after the call in milliseconds in case the task did throw an exception. This is important in case of an error the task does not start to spin. This must be a number between 0 and n.
	*/
	property name="howLongToSleepAfterTheCallWhenError" type="numeric" default=60000;



	/**
	* How long in milliseconds, should we wait for this task to end?
	*/
	property name="howLongToWaitForTaskOnStop" type="numeric" default=10000;

	/**
	* force a stop of the task, if it does not end on it's own
	*/
	property name="forceStop" type="boolean" default=false;

	/**
	* This function is called to execute the Task, in case of an errror the information get logged and the task will be invoked again.
	*/
	public abstract void function invoke(required string id,required numeric iterations, required numeric errors, numeric lastExecutionTime, date lastExecutionDate, struct lastError);
}