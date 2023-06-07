component {
	
    // we do this cfc, because Lucee does not unload a component when updating the extension

	public void function init(string id, struct config, component listener) { 
		variables.id=arguments.id?:"";
        variables.config=arguments.config?:{};
	}

	public void function start() {
		variables.instance=new TasksGatewayImpl(variables.id,variables.config);
        variables.instance.start();
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