component {
	
	static {
		static.instances={};
	}

    // we do this cfc, because Lucee does not unload a component when updating the extension

	public void function init(string id, struct config, component listener) { 
		variables.id=arguments.id?:"";
        variables.config=arguments.config?:{};
	}
	
	public void function start() {
		lock name="tasks-gateway-#variables.id#-lock" timeout=10 {
			// workaround for LDEV-6246: stop orphaned instance from previous load
			if(structKeyExists(static.instances, variables.id)) {
				static.instances[variables.id].stop();
				structDelete(static.instances, variables.id);
			}

			variables.instance = new TasksGatewayImpl(variables.id, variables.config);
			variables.instance.start();
			static.instances[variables.id] = variables.instance;
		}
	}

	public void function stop() {
        variables.instance.stop();
        variables.instance=nullValue();
	}

	public void function restart() {
        stop();
        start();
	}

	public string function getState() {
		if(isNull(variables.instance)) return "stopped";
		return variables.instance.getState();
	}

	public string function setState(state) {
		variables.instance.setState(state);
	}

	public string function sendMessage(struct data) {
        return variables.instance.sendMessage(data);
	}

}