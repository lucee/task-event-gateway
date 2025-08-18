component extends="org.lucee.cfml.test.LuceeTestCase" labels="tasks" {
    /*

    the lucee test suite runs without a http server, so the tasks stuff can't be unit tested

    the test suite fails if no matching tests are found, so this is a no-op test so CI passes

    */ 
    function testNothing() {
        expect (true ).toBeTrue();
    }
}