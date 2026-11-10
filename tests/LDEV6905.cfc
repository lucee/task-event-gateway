component extends="org.lucee.cfml.test.LuceeTestCase" labels="tasks" {

	/*
	 * LDEV-6905: the gateway setting "package" accepts a comma-separated list or an array,
	 * so one instance can load tasks from more than one package. A single package string
	 * keeps working as before. Tasks with the same simple name in different packages are
	 * both loaded and are identified by their full component name.
	 */

	function beforeAll() {
		variables.dirName = "ldev6905" & hash( createUUID(), "quick" );
		variables.dir = getDirectoryFromPath( getCurrentTemplatePath() ) & variables.dirName & "/";
		var myName = getComponentMetadata( this ).fullname;
		variables.basePkg = ( listLen( myName, "." ) > 1 ? listDeleteAt( myName, listLen( myName, "." ), "." ) & "." : "" ) & variables.dirName;
		variables.pkgCore = variables.basePkg & ".core";
		variables.pkgOptional = variables.basePkg & ".optional";
		variables.pkgMissing = variables.basePkg & ".doesNotExist";
		variables.dirCore = variables.dir & "core/";
		variables.dirOptional = variables.dir & "optional/";
		directoryCreate( variables.dirCore );
		directoryCreate( variables.dirOptional );

		writeTask( variables.dirCore & "CoreWorker.cfc", "core" );
		writeTask( variables.dirCore & "SharedName.cfc", "core-shared" );
		writeTask( variables.dirOptional & "OptionalWorker.cfc", "optional" );
		writeTask( variables.dirOptional & "SharedName.cfc", "optional-shared" );
		fileWrite( variables.dirCore & "Helper.cfc", "component {}" );
	}

	function afterAll() {
		if ( directoryExists( variables.dir ) ) directoryDelete( variables.dir, true );
	}

	function run( testResults, testBox ) {
		describe( "LDEV-6905 support multiple packages in the gateway package setting", function() {

			it( "still loads tasks from a single package string", function() {
				var cfcs = newGateway( variables.pkgCore ).loadCFCs();
				expect( cfcs ).toHaveKey( variables.pkgCore & ".CoreWorker" );
				expect( cfcs ).toHaveKey( variables.pkgCore & ".SharedName" );
				expect( cfcs ).toHaveKey( variables.pkgCore & ".Helper" );
				expect( cfcs ).notToHaveKey( variables.pkgOptional & ".OptionalWorker" );
				expect( cfcs[ variables.pkgCore & ".CoreWorker" ].type ).toBe( "task" );
				expect( cfcs[ variables.pkgCore & ".Helper" ].type ).toBe( "other" );
				expect( arrayLen( taskNames( cfcs ) ) ).toBe( 2 );
			});

			it( "loads tasks from every package in a comma-separated list", function() {
				var gw = newGateway( variables.pkgCore & ", " & variables.pkgOptional );
				var cfcs = gw.loadCFCs();
				expect( cfcs[ variables.pkgCore & ".CoreWorker" ].type ).toBe( "task" );
				expect( cfcs[ variables.pkgOptional & ".OptionalWorker" ].type ).toBe( "task" );
				expect( arrayLen( taskNames( cfcs ) ) ).toBe( 4 );

				var info = deserializeJson( gw.sendMessage( { action: "info" } ) );
				expect( info.packages ).toBe( [ variables.pkgCore, variables.pkgOptional ] );
				expect( info.package ).toBe( variables.pkgCore & "," & variables.pkgOptional );
			});

			it( "loads tasks from an array of packages", function() {
				var cfcs = newGateway( [ variables.pkgCore, variables.pkgOptional ] ).loadCFCs();
				expect( cfcs ).toHaveKey( variables.pkgCore & ".CoreWorker" );
				expect( cfcs ).toHaveKey( variables.pkgOptional & ".OptionalWorker" );
				expect( arrayLen( taskNames( cfcs ) ) ).toBe( 4 );
			});

			it( "trims entries and ignores empty ones in a comma-separated list", function() {
				var gw = newGateway( " , " & variables.pkgCore & " ,," & variables.pkgOptional & ", " );
				var cfcs = gw.loadCFCs();
				expect( arrayLen( taskNames( cfcs ) ) ).toBe( 4 );
				var info = deserializeJson( gw.sendMessage( { action: "info" } ) );
				expect( info.packages ).toBe( [ variables.pkgCore, variables.pkgOptional ] );
			});

			it( "identifies tasks with the same simple name in different packages by their full component name", function() {
				var cfcs = newGateway( [ variables.pkgCore, variables.pkgOptional ] ).loadCFCs();
				expect( cfcs ).toHaveKey( variables.pkgCore & ".SharedName" );
				expect( cfcs ).toHaveKey( variables.pkgOptional & ".SharedName" );
				expect( cfcs[ variables.pkgCore & ".SharedName" ].type ).toBe( "task" );
				expect( cfcs[ variables.pkgOptional & ".SharedName" ].type ).toBe( "task" );
				expect( cfcs[ variables.pkgCore & ".SharedName" ].name ).toBe( variables.pkgCore & ".SharedName" );
				expect( cfcs[ variables.pkgOptional & ".SharedName" ].name ).toBe( variables.pkgOptional & ".SharedName" );
				expect( createObject( "component", variables.pkgCore & ".SharedName" ).getVersion() ).toBe( "core-shared" );
				expect( createObject( "component", variables.pkgOptional & ".SharedName" ).getVersion() ).toBe( "optional-shared" );
			});

			it( "skips a package that does not exist and still loads the others", function() {
				var cfcs = newGateway( variables.pkgMissing & "," & variables.pkgCore ).loadCFCs();
				expect( cfcs ).toHaveKey( variables.pkgCore & ".CoreWorker" );
				expect( arrayLen( taskNames( cfcs ) ) ).toBe( 2 );
			});

			it( "drops duplicate package entries, keeping the first", function() {
				var gw = newGateway( variables.pkgCore & "," & variables.pkgCore & "," & uCase( variables.pkgCore ) );
				var info = deserializeJson( gw.sendMessage( { action: "info" } ) );
				expect( info.packages ).toBe( [ variables.pkgCore ] );
				expect( arrayLen( taskNames( gw.loadCFCs() ) ) ).toBe( 2 );
			});

			it( "still detects a change in one package without touching tasks from another", function() {
				var gw = newGateway( [ variables.pkgCore, variables.pkgOptional ] );
				var cfcs = gw.loadCFCs();
				writeTask( variables.dirOptional & "OptionalWorker.cfc", "optional-changed" );
				touch( variables.dirOptional & "OptionalWorker.cfc" );
				cfcs = gw.loadCFCs( cfcs );
				expect( cfcs[ variables.pkgOptional & ".OptionalWorker" ].status ).toBe( "modified" );
				expect( cfcs[ variables.pkgCore & ".CoreWorker" ].status ).toBe( "existing" );
			});
		});
	}

	private function taskNames( required struct cfcs ) {
		var names = [];
		loop struct=arguments.cfcs index="local.name" item="local.el" {
			if ( el.type == "task" ) arrayAppend( names, name );
		}
		return names;
	}

	private function newGateway( required any package ) {
		var gw = new org.lucee.cfml.TasksGatewayImpl();
		gw.init( "ldev6905", {
			package: arguments.package,
			checkForChangeInterval: 1,
			checkForChangeBaseInterval: 0,
			logName: "application"
		} );
		return gw;
	}

	private function writeTask( required string path, required string version ) {
		fileWrite( arguments.path, 'component extends="org.lucee.cfml.Task" {
	public void function invoke(required string id, required numeric iterations, required numeric errors, numeric lastExecutionTime, date lastExecutionDate, struct lastError) {}
	public string function getVersion() { return "#arguments.version#"; }
}' );
	}

	// make sure the last modified date differs from the previous one, independent of the resolution of the file system
	private function touch( required string path ) {
		variables.touchOffset = ( variables.touchOffset ?: 0 ) + 1;
		fileSetLastModified( arguments.path, dateAdd( "n", variables.touchOffset, now() ) );
	}
}
