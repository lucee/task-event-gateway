component extends="org.lucee.cfml.test.LuceeTestCase" labels="tasks" {

	/*
	 * LDEV-6784: the action "reload" of sendGatewayMessage marks all tasks and listeners as changed,
	 * with the next check for changes they are loaded again, like when their own file had changed.
	 */

	function beforeAll() {
		variables.dirName = "ldev6784" & hash( createUUID(), "quick" );
		variables.dir = getDirectoryFromPath( getCurrentTemplatePath() ) & variables.dirName & "/";
		var myName = getComponentMetadata( this ).fullname;
		variables.pkg = ( listLen( myName, "." ) > 1 ? listDeleteAt( myName, listLen( myName, "." ), "." ) & "." : "" ) & variables.dirName;
		directoryCreate( variables.dir );

		fileWrite( variables.dir & "BaseTask.cfc", 'abstract component extends="org.lucee.cfml.Task" {
	public void function invoke(required string id, required numeric iterations, required numeric errors, numeric lastExecutionTime, date lastExecutionDate, struct lastError) {}
}' );
		fileWrite( variables.dir & "MyTask.cfc", 'component extends="BaseTask" {}' );
		fileWrite( variables.dir & "OtherTask.cfc", 'component extends="BaseTask" {}' );
		fileWrite( variables.dir & "MyListener.cfc", 'component extends="org.lucee.cfml.Listener" {
	public void function onError(struct error,component instance, string task, required string id,required numeric iterations, required numeric errors, numeric lastExecutionTime, date lastExecutionDate, struct lastError) {}
	public void function onExecutionStart(component instance, string task, required string id,required numeric iterations, required numeric errors, numeric lastExecutionTime, date lastExecutionDate, struct lastError) {}
	public void function onExecutionEnd(component instance, string task, required string id,required numeric iterations, required numeric errors, numeric lastExecutionTime, date lastExecutionDate, struct lastError) {}
}' );
		fileWrite( variables.dir & "Helper.cfc", 'component {}' );
	}

	function afterAll() {
		if ( directoryExists( variables.dir ) ) directoryDelete( variables.dir, true );
	}

	function run( testResults, testBox ) {
		describe( "LDEV-6784 reload all tasks with sendGatewayMessage", function() {

			it( "does not reload anything without a reload request", function() {
				var gw = newGateway( 1 );
				var cfcs = gw.loadCFCs();
				cfcs = gw.loadCFCs( cfcs );
				expect( statusOf( cfcs, "MyTask" ) ).toBe( "existing" );
				expect( statusOf( cfcs, "OtherTask" ) ).toBe( "existing" );
				expect( statusOf( cfcs, "MyListener" ) ).toBe( "existing" );
				expect( statusOf( cfcs, "Helper" ) ).toBe( "existing" );
			});

			it( "reloads all tasks and listeners with the next check, although no file has changed", function() {
				var gw = newGateway( 1 );
				var cfcs = gw.loadCFCs();
				var lastModified = cfcs[ variables.pkg & ".MyTask" ].lastModified;
				expect( gw.getChangeReason( cfcs[ variables.pkg & ".MyTask" ], {}, true ) ).toBe( "" );

				expect( gw.sendMessage( { action: "reload" } ) ).toBe( 1 );
				expect( gw.getChangeReason( cfcs[ variables.pkg & ".MyTask" ], {}, false ) ).toInclude( "reload" );

				cfcs = gw.loadCFCs( cfcs );
				expect( statusOf( cfcs, "MyTask" ) ).toBe( "modified" );
				expect( statusOf( cfcs, "OtherTask" ) ).toBe( "modified" );
				expect( statusOf( cfcs, "MyListener" ) ).toBe( "modified" );
				expect( cfcs[ variables.pkg & ".MyTask" ].type ).toBe( "task" );
				expect( cfcs[ variables.pkg & ".MyListener" ].type ).toBe( "listener" );
				expect( cfcs[ variables.pkg & ".MyTask" ].reloadReason ).toInclude( "reload" );
				expect( cfcs[ variables.pkg & ".MyTask" ].reloadGeneration ).toBe( 1 );
				// the files have not changed
				expect( cfcs[ variables.pkg & ".MyTask" ].lastModified ).toBe( lastModified );
				// listener and task are new instances
				expect( isObject( cfcs[ variables.pkg & ".MyListener" ].instance ) ).toBeTrue();

				// it is handled only once
				cfcs = gw.loadCFCs( cfcs );
				expect( statusOf( cfcs, "MyTask" ) ).toBe( "existing" );
				expect( statusOf( cfcs, "OtherTask" ) ).toBe( "existing" );
				expect( statusOf( cfcs, "MyListener" ) ).toBe( "existing" );
				expect( gw.getChangeReason( cfcs[ variables.pkg & ".MyTask" ], {}, true ) ).toBe( "" );
			});

			it( "does not depend on the check of the base components", function() {
				var gw = newGateway( 0 );
				var cfcs = gw.loadCFCs();
				gw.requestReload();
				cfcs = gw.loadCFCs( cfcs );
				expect( statusOf( cfcs, "MyTask" ) ).toBe( "modified" );
				expect( statusOf( cfcs, "OtherTask" ) ).toBe( "modified" );
			});

			it( "handles several requests before the next check as one", function() {
				var gw = newGateway( 1 );
				var cfcs = gw.loadCFCs();
				gw.requestReload();
				gw.requestReload();
				expect( gw.sendMessage( { action: "reload" } ) ).toBe( 3 );
				cfcs = gw.loadCFCs( cfcs );
				expect( statusOf( cfcs, "MyTask" ) ).toBe( "modified" );
				expect( cfcs[ variables.pkg & ".MyTask" ].reloadGeneration ).toBe( 3 );
				cfcs = gw.loadCFCs( cfcs );
				expect( statusOf( cfcs, "MyTask" ) ).toBe( "existing" );
			});

			it( "does not reload with a request that was already handled by the initial load", function() {
				var gw = newGateway( 1 );
				gw.requestReload();
				var cfcs = gw.loadCFCs();
				expect( cfcs[ variables.pkg & ".MyTask" ].reloadGeneration ).toBe( 1 );
				cfcs = gw.loadCFCs( cfcs );
				expect( statusOf( cfcs, "MyTask" ) ).toBe( "existing" );
			});

			it( "does not touch other gateway instances", function() {
				var gw1 = newGateway( 1 );
				var gw2 = newGateway( 1 );
				var cfcs1 = gw1.loadCFCs();
				var cfcs2 = gw2.loadCFCs();
				gw1.requestReload();
				cfcs1 = gw1.loadCFCs( cfcs1 );
				cfcs2 = gw2.loadCFCs( cfcs2 );
				expect( statusOf( cfcs1, "MyTask" ) ).toBe( "modified" );
				expect( statusOf( cfcs2, "MyTask" ) ).toBe( "existing" );
				expect( gw2.getReloadGeneration() ).toBe( 0 );
			});

			it( "still reloads a task that has changed on its own at the same time", function() {
				var gw = newGateway( 0 );
				var cfcs = gw.loadCFCs();
				var path = variables.dir & "MyTask.cfc";
				fileWrite( path, 'component extends="BaseTask" { /* changed */ }' );
				touch( path );
				gw.requestReload();
				cfcs = gw.loadCFCs( cfcs );
				expect( statusOf( cfcs, "MyTask" ) ).toBe( "modified" );
				expect( statusOf( cfcs, "OtherTask" ) ).toBe( "modified" );
				cfcs = gw.loadCFCs( cfcs );
				expect( statusOf( cfcs, "MyTask" ) ).toBe( "existing" );
			});

			it( "reports the reload generation with the action info", function() {
				var gw = newGateway( 1 );
				gw.loadCFCs();
				expect( deserializeJson( gw.sendMessage( { action: "info" } ) ).reloadGeneration ).toBe( 0 );
				gw.sendMessage( { action: "reload" } );
				expect( deserializeJson( gw.sendMessage( { action: "info" } ) ).reloadGeneration ).toBe( 1 );
			});

			it( "lists the reload action in the usage", function() {
				var gw = newGateway( 1 );
				expect( gw.sendMessage( {} ) ).toInclude( "reload" );
			});
		});
	}

	private function statusOf( required struct cfcs, required string name ) {
		return cfcs[ variables.pkg & "." & arguments.name ].status;
	}

	private function newGateway( required numeric baseInterval ) {
		var gw = new org.lucee.cfml.TasksGatewayImpl();
		gw.init( "ldev6784", {
			package: variables.pkg,
			checkForChangeInterval: 1,
			checkForChangeBaseInterval: arguments.baseInterval,
			logName: "application"
		} );
		return gw;
	}

	// make sure the last modified date differs from the previous one, independent of the resolution of the file system
	private function touch( required string path ) {
		variables.touchOffset = ( variables.touchOffset ?: 0 ) + 1;
		fileSetLastModified( arguments.path, dateAdd( "n", variables.touchOffset, now() ) );
	}
}
