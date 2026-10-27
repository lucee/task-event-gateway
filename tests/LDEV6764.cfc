component extends="org.lucee.cfml.test.LuceeTestCase" labels="tasks" {

	/*
	 * LDEV-6764: a change in a base component (extends) or an interface (implements) of a task
	 * has to be detected, so the task gets reloaded.
	 */

	function beforeAll() {
		variables.dirName = "ldev6764" & hash( createUUID(), "quick" );
		variables.dir = getDirectoryFromPath( getCurrentTemplatePath() ) & variables.dirName & "/";
		var myName = getComponentMetadata( this ).fullname;
		variables.pkg = ( listLen( myName, "." ) > 1 ? listDeleteAt( myName, listLen( myName, "." ), "." ) & "." : "" ) & variables.dirName;
		directoryCreate( variables.dir );

		writeBase( "v1" );
		writeInterface( "v1" );
		fileWrite( variables.dir & "MyTask.cfc", 'component extends="BaseTask" {}' );
		fileWrite( variables.dir & "MyInterfaceTask.cfc", 'component extends="org.lucee.cfml.Task" implements="IMyTask" {
	public void function invoke(required string id, required numeric iterations, required numeric errors, numeric lastExecutionTime, date lastExecutionDate, struct lastError) {}
	public string function getVersion() { return "task"; }
}' );
		fileWrite( variables.dir & "Helper.cfc", 'component {}' );
	}

	function afterAll() {
		if ( directoryExists( variables.dir ) ) directoryDelete( variables.dir, true );
	}

	function run( testResults, testBox ) {
		describe( "LDEV-6764 detect changes in base components and interfaces of tasks", function() {

			it( "collects the base components and interfaces of a task", function() {
				var cfcs = newGateway( 1 ).loadCFCs();
				var task = cfcs[ variables.pkg & ".MyTask" ];
				expect( task.type ).toBe( "task" );
				expect( hasChainEntry( task.chain, "BaseTask.cfc" ) ).toBeTrue();
				// the base components of this extension are not part of the chain
				expect( structCount( task.chain ) ).toBe( 1 );
				expect( task.chainHash ).notToBe( "" );

				var task2 = cfcs[ variables.pkg & ".MyInterfaceTask" ];
				expect( task2.type ).toBe( "task" );
				expect( hasChainEntry( task2.chain, "IMyTask.cfc" ) ).toBeTrue();

				// the base component, the interface and the helper are stored, but not as a task
				expect( cfcs[ variables.pkg & ".BaseTask" ].type ).toBe( "other" );
				expect( cfcs[ variables.pkg & ".IMyTask" ].type ).toBe( "other" );
				expect( cfcs[ variables.pkg & ".Helper" ].type ).toBe( "other" );
			});

			it( "does not reload anything when nothing has changed", function() {
				var gw = newGateway( 1 );
				var cfcs = gw.loadCFCs();
				sleep( 1100 );
				cfcs = gw.loadCFCs( cfcs );
				loop struct=cfcs index="local.name" item="local.el" {
					expect( el.status ).toBe( "existing", name );
					expect( gw.getChangeReason( el, {}, true ) ).toBe( "", name );
				}
			});

			it( "detects a change in a base component", function() {
				var gw = newGateway( 1 );
				var cfcs = gw.loadCFCs();
				expect( createObject( "component", variables.pkg & ".MyTask" ).getVersion() ).toBe( "v1" );

				writeBase( "v2" );
				var reason = gw.getChangeReason( cfcs[ variables.pkg & ".MyTask" ], {}, true );
				expect( reason ).toInclude( "BaseTask.cfc" );
				// the own file has not changed, so without checking the base nothing is detected
				expect( gw.getChangeReason( cfcs[ variables.pkg & ".MyTask" ], {}, false ) ).toBe( "" );

				sleep( 1100 ); // base interval
				cfcs = gw.loadCFCs( cfcs );
				expect( cfcs[ variables.pkg & ".MyTask" ].status ).toBe( "modified" );
				expect( cfcs[ variables.pkg & ".MyTask" ].type ).toBe( "task" );
				expect( cfcs[ variables.pkg & ".MyInterfaceTask" ].status ).toBe( "existing" );
				expect( createObject( "component", variables.pkg & ".MyTask" ).getVersion() ).toBe( "v2" );

				// next cycle everything is stable again
				sleep( 1100 );
				cfcs = gw.loadCFCs( cfcs );
				expect( cfcs[ variables.pkg & ".MyTask" ].status ).toBe( "existing" );
			});

			it( "detects a change in an interface", function() {
				var gw = newGateway( 1 );
				var cfcs = gw.loadCFCs();
				writeInterface( "v2" );
				sleep( 1100 );
				cfcs = gw.loadCFCs( cfcs );
				expect( cfcs[ variables.pkg & ".MyInterfaceTask" ].status ).toBe( "modified" );
				expect( cfcs[ variables.pkg & ".MyTask" ].status ).toBe( "existing" );
			});

			it( "does not check the base components when checkForChangeBaseInterval is 0", function() {
				var gw = newGateway( 0 );
				var cfcs = gw.loadCFCs();
				writeBase( "v3" );
				sleep( 1100 );
				cfcs = gw.loadCFCs( cfcs );
				expect( cfcs[ variables.pkg & ".MyTask" ].status ).toBe( "existing" );
			});

			it( "still detects a change of the task itself", function() {
				var gw = newGateway( 0 );
				var cfcs = gw.loadCFCs();
				var path = variables.dir & "MyTask.cfc";
				fileWrite( path, 'component extends="BaseTask" { /* changed */ }' );
				touch( path );
				cfcs = gw.loadCFCs( cfcs );
				expect( cfcs[ variables.pkg & ".MyTask" ].status ).toBe( "modified" );
				expect( gw.getChangeReason( cfcs[ variables.pkg & ".MyTask" ], {}, false ) ).toBe( "" );
			});
		});
	}

	private function newGateway( required numeric baseInterval ) {
		var gw = new org.lucee.cfml.TasksGatewayImpl();
		gw.init( "ldev6764", {
			package: variables.pkg,
			checkForChangeInterval: 1,
			checkForChangeBaseInterval: arguments.baseInterval,
			logName: "application"
		} );
		return gw;
	}

	private boolean function hasChainEntry( required struct chain, required string fileName ) {
		loop struct=arguments.chain index="local.path" item="local.lastModified" {
			if ( getFileFromPath( path ) == arguments.fileName ) return true;
		}
		return false;
	}

	private function writeBase( required string version ) {
		var path = variables.dir & "BaseTask.cfc";
		fileWrite( path, 'abstract component extends="org.lucee.cfml.Task" {
	public void function invoke(required string id, required numeric iterations, required numeric errors, numeric lastExecutionTime, date lastExecutionDate, struct lastError) {}
	public string function getVersion() { return "#arguments.version#"; }
}' );
		touch( path );
	}

	private function writeInterface( required string version ) {
		var path = variables.dir & "IMyTask.cfc";
		fileWrite( path, 'interface {
	public string function getVersion(); // #arguments.version#
}' );
		touch( path );
	}

	// make sure the last modified date differs from the previous one, independent of the resolution of the file system
	private function touch( required string path ) {
		variables.touchOffset = ( variables.touchOffset ?: 0 ) + 1;
		fileSetLastModified( arguments.path, dateAdd( "n", variables.touchOffset, now() ) );
	}
}
