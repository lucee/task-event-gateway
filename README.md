# Tasks Event Gateway (TEG)

This extension adds the ability to run self-configured Tasks when installed into Lucee Server.

## Build

The extension is a Maven project (which invokes Ant internally). To build it, you need Maven installed on your machine. Once available, simply run:

```
mvn package
```

within the project root. The resulting `.lex` file will be created in the `target` folder.

> Ant does not need to be installed separately — it is invoked by the `maven-antrun-plugin` as part of the Maven build.

## Installation

Copy the generated `.lex` file to the `/lucee-server/deploy` folder of your Lucee installation.

## Configuration

Configuration happens in two places: the gateway instance configuration for global settings, and each Task/Listener implementation for Task/Listener-specific settings.

### Gateway Instance Configuration

> **Changed in 1.1.0.0:** The extension no longer installs a gateway instance automatically. You must configure the gateway instance manually — either via `.CFConfig.json` or through the Lucee Administrator.

To register a gateway instance via `.CFConfig.json`, add an entry under the `gateways` key:

```json
{
  "gateways": {
    "my-task": {
      "cfcPath": "org.lucee.cfml.TasksGateway",
      "listenerCFCPath": "",
      "startupMode": "automatic",
      "custom": {
        "package": "core.tasks",
        "templatePath": "/cron",
        "checkForChangeInterval": 10,
        "checkForChangeNoMatchInterval": 60,
        "settingLocation": "",
        "checkForChangeSettingInterval": 0,
        "logName": "scheduler"
      },
      "readOnly": "true"
    }
  }
}
```

The `custom` fields control the TEG behaviour:

| Setting | Description |
|---|---|
| `package` | The component package the TEG scans for Task/Listener CFCs (e.g. `core.tasks` maps to `/core/tasks`) |
| `templatePath` | Absolute path, mapping, or webroot-relative path to a folder containing `.cfm`-based tasks |
| `checkForChangeInterval` | Seconds between file-change checks for templates previously identified as tasks. Higher values reduce I/O but slow down detection of code changes |
| `checkForChangeNoMatchInterval` | Seconds between file-change checks for templates that were **not** identified as tasks in the previous check. Typically set higher than `checkForChangeInterval` |
| `settingLocation` | Cache definition name used to persist task settings (e.g. paused state) across server instances. Leave empty if not needed |
| `checkForChangeSettingInterval` | Seconds between checks for setting changes in the `settingLocation` cache. When server A pauses a task, this is the maximum delay before server B picks up the change |
| `logName` | Name of the Lucee log file the TEG writes to (default: `application`) |

The TEG uses four log levels:

- **debug** — logged during regular task execution
- **info** — logged when tasks are added, modified, or removed
- **warn** — logged when a task fails to execute
- **error** — logged when the TEG itself encounters an unexpected exception

#### Configuration via Environment Variables or System Properties

The gateway instance custom settings can also be supplied via environment variables or JVM system properties. Note that values set in the gateway instance configuration (`.CFConfig.json` or the Lucee Admin) always take precedence.

The table below lists each environment variable alongside its system property equivalent:

| Environment Variable | System Property | Default |
|---|---|---|
| `TASKS_EVENT_GATEWAY_PACKAGE` | `tasks.event.gateway.package` | `org.lucee.cfml.tasks` |
| `TASKS_EVENT_GATEWAY_TEMPLATE_PATH` | `tasks.event.gateway.template.path` | *(empty)* |
| `TASKS_EVENT_GATEWAY_TEMPLATE_PATH_RECURSIVE` | `tasks.event.gateway.template.path.recursive` | `true` |
| `TASKS_EVENT_GATEWAY_CHECKFORCHANGEINTERVAL` | `tasks.event.gateway.checkForChangeInterval` | `10` |
| `TASKS_EVENT_GATEWAY_CHECKFORCHANGEINTERVAL` | `tasks.event.gateway.checkForChangeNoMatchInterval` | `60` |
| `TASKS_EVENT_GATEWAY_SETTINGLOCATION` | `tasks.event.gateway.settinglocation` | *(empty)* |
| `TASKS_EVENT_GATEWAY_CHECKFORCHANGESETTINGINTERVAL` | `tasks.event.gateway.checkForChangeSettingInterval` | `0` |
| `TASKS_EVENT_GATEWAY_LOG` | `tasks.event.gateway.log` | `application` |

### Task Configuration

Each task configures itself via `property` declarations:

```cfc
property name="concurrentThreadCount"           type="numeric" default=1;
property name="howLongToSleepBeforeTheCall"     type="numeric" default=1000;
property name="howLongToSleepAfterTheCall"      type="numeric" default=1000;
property name="howLongToSleepAfterTheCallWhenError" type="numeric" default=10000;
property name="howLongToWaitForTaskOnStop"      type="numeric" default=10000;
property name="forceStop"                       type="boolean" default=true;
```

Full documentation for each property is in `/source/components/org/lucee/cfml/Task.cfc`.

One setting worth highlighting: `howLongToSleepAfterTheCallWhenError` controls how long a task pauses after an exception. This is critical — you generally want a task to **slow down** after an error, not spin rapidly and flood the logs.

### Listener Configuration

Each listener configures which tasks it applies to via `allow` and `deny` properties:

```cfc
property name="allow" type="string" default="*";
property name="deny"  type="string" default="";
```

Full documentation is in `/source/components/org/lucee/cfml/Listener.cfc`.

---

## Creating a Task

The TEG scans the component package defined in the gateway instance configuration (e.g. `core.tasks`, which maps to `/core/tasks`). Any component in that package that extends `org.lucee.cfml.Task` is automatically picked up and executed.

```cfc
component extends="org.lucee.cfml.Task" {

    property name="concurrentThreadCount"               type="numeric" default=1;
    property name="howLongToSleepBeforeTheCall"         type="numeric" default=1000;
    property name="howLongToSleepAfterTheCall"          type="numeric" default=1000;
    property name="howLongToSleepAfterTheCallWhenError" type="numeric" default=10000;
    property name="howLongToWaitForTaskOnStop"          type="numeric" default=10000;
    property name="forceStop"                           type="boolean" default=true;

    public function init() {
        systemOutput("----- INIT -----", 1, 1);
    }

    public void function invoke(
        required string id,
        required numeric iterations,
        required numeric errors,
        numeric lastExecutionTime,
        date lastExecutionDate,
        struct lastError
    ) {
        systemOutput("---- #id# it:#iterations# err:#errors# last:#lastExecutionDate?:'<none>'# last-time:#lastExecutionTime?:'<none>'# #now()# -----", 1, 1);
        sleep(randRange(1000, 5000));
    }
}
```

All properties have defaults inherited from the abstract component and are therefore optional.

## .cfm-Based Tasks

Tasks can also be defined as plain `.cfm` templates. This is useful for reusing existing scheduled tasks without rewriting them. These tasks are executed as internal requests, so `Application.cfc` runs first.

Set the `templatePath` in the gateway instance configuration to the folder containing your templates. Each template must include the following metadata comment to be recognised as a task:

```cfm
<!---
@task                           "CFML Dummy Task"
@description                    "This CFML Dummy Task is just to show the functionality"
@concurrentThreadCount          1
@howLongToSleepBeforeTheCall    2000
@howLongToSleepAfterTheCall     2000
@howLongToSleepAfterTheCallWhenError 10000
@howLongToWaitForTaskOnStop     10000
@forceStop                      true
--->
```

These settings follow the same rules as property-based task configuration. Inside the template, the same arguments passed to `invoke()` are available via the `url` scope:

- `url.id`
- `url.iterations`
- `url.errors`
- `url.lastExecutionTime`
- `url.lastExecutionDate`
- `url.lastError`

---

## Creating a Listener

Listeners are defined the same way as tasks — they just extend a different base component. Create a component that extends `org.lucee.cfml.Listener` and implement its abstract functions:

```cfc
component extends="org.lucee.cfml.Listener" {

    property name="allow" type="string" default="*";
    property name="deny"  type="string" default="";

    public void function onError(
        struct error,
        component instance,
        string task,
        required string id,
        required numeric iterations,
        required numeric errors,
        numeric lastExecutionTime,
        date lastExecutionDate,
        struct lastError
    ) {
        systemOutput("----- MyListener.onError -----", 1, 1);
        systemOutput(error.message, 1, 1);
    }

    public void function onExecutionStart(
        component instance,
        string task,
        required string id,
        required numeric iterations,
        required numeric errors,
        numeric lastExecutionTime,
        date lastExecutionDate,
        struct lastError
    ) {
        systemOutput("----- MyListener.onExecutionStart -----", 1, 1);
        if (!isNull(lastError)) lastError = lastError.message;
        systemOutput(arguments, 1, 1);
    }

    public void function onExecutionEnd(
        component instance,
        string task,
        required string id,
        required numeric iterations,
        required numeric errors,
        numeric lastExecutionTime,
        date lastExecutionDate,
        struct lastError
    ) {
        systemOutput("----- MyListener.onExecutionEnd -----", 1, 1);
        if (!isNull(lastError)) lastError = lastError.message;
        systemOutput(arguments, 1, 1);
    }
}
```

All properties have defaults inherited from the abstract component and are therefore optional.