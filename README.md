# Tasks Event Gateway (TEG)

The Tasks Event Gateway extension adds long-running background tasks to Lucee Server. Unlike cron-style schedulers that fire at fixed intervals, each task runs in its own thread loop and controls its own timing — sleep before/after execution, backoff on errors, and optional concurrency.

Use it when you need always-on workers (queue consumers, polling loops, sync jobs) rather than calendar-based scheduling. For cron expressions and one-shot jobs, see the [Quartz Scheduler extension](https://docs.lucee.org/recipes/scheduler-quartz.html).

## Requirements

- Lucee Server (single- or multi-context)
- A configured gateway instance (not created automatically since extension 1.1.0.0)

## Quick start

1. Install the extension (see [Installation](#installation)).
2. Register a gateway instance in `.CFConfig.json` or the Lucee Administrator (see [Configuration](#configuration)).
3. Create a CFC in your configured package that extends `org.lucee.cfml.Task` and implements `invoke()`.
4. Start (or restart) the gateway instance and check the configured log file for `Tasks Event Gateway:` entries.

## Build

The extension is a Maven project (which invokes Ant internally). To build it, you need Maven installed on your machine. Once available, simply run:

```bash
mvn package
```

within the project root. The resulting `.lex` file will be created in the `target` folder.

> Ant does not need to be installed separately — it is invoked by the `maven-antrun-plugin` as part of the Maven build.

## Installation

Install via the Lucee Administrator (**Extensions → Available**), or use any method described in the [Extension Installation recipe](https://docs.lucee.org/recipes/extension-installation.html).

Manual deploy: copy the generated `.lex` file to the `/lucee-server/deploy` folder of your Lucee installation. Lucee detects and installs it within about a minute.

- **Maven GAV:** `org.lucee:tasks-extension`
- **Extension ID:** `947C02B0-7AE4-4054-938A8E059DD7625A`
- **Source:** [github.com/lucee/task-event-gateway](https://github.com/lucee/task-event-gateway)
- **Downloads:** [download.lucee.org](https://download.lucee.org/#947C02B0-7AE4-4054-938A8E059DD7625A)

## Configuration

Configuration happens in two places: the gateway instance configuration for global settings, and each Task/Listener implementation for task-specific settings.

You can run multiple gateway instances (each with its own ID, package, and log). Use a shared cache in `settingLocation` when several servers need to share pause/resume state.

### Gateway instance configuration

> **Changed in 1.1.0.0:** The extension no longer installs a gateway instance automatically. You must configure the gateway instance manually — either via `.CFConfig.json` or through **Services → Event Gateways** in the Lucee Administrator.

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
        "templatePathRecursive": true,
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

In the Administrator, choose gateway type **Tasks**, set the instance ID (e.g. `my-task`), and fill in the same custom fields.

The `custom` fields control TEG behaviour:

| Setting | Description |
|---|---|
| `package` | Component package the TEG scans for Task/Listener CFCs (e.g. `core.tasks` maps to `/core/tasks`) |
| `templatePath` | Absolute path, mapping, or webroot-relative path to a folder containing `.cfm`-based tasks |
| `templatePathRecursive` | When `true` (default), scan `templatePath` recursively for `.cfm` task templates |
| `checkForChangeInterval` | Seconds between file-change checks for components/templates already identified as tasks. Higher values reduce I/O but slow detection of code changes |
| `checkForChangeNoMatchInterval` | Seconds between checks for files that were **not** tasks on the previous scan. Keep this higher when the folder contains many non-task files |
| `settingLocation` | Cache definition name used to persist task settings (e.g. paused state) across server instances. Leave empty if not needed |
| `checkForChangeSettingInterval` | Seconds between checks for setting changes in `settingLocation`. When server A pauses a task, this is the maximum delay before server B picks up the change (`0` = disabled) |
| `logName` | Lucee log file the TEG writes to (default: `application`) |

Gateway instance settings take precedence over environment variables and JVM system properties.

#### Activator

The activator is a component whose `active()` method returns whether the gateway should run. Default: `org.lucee.cfml.tasks.Activator` (always active). Override via JVM system property or environment variable only:

| Environment Variable | System Property | Default |
|---|---|---|
| `TASKS_EVENT_GATEWAY_ACTIVATOR` | `tasks.event.gateway.activator` | `org.lucee.cfml.tasks.Activator` |

Use a custom activator for maintenance windows, feature flags, or cluster leadership.

#### Configuration via environment variables or system properties

| Environment Variable | System Property | Default |
|---|---|---|
| `TASKS_EVENT_GATEWAY_PACKAGE` | `tasks.event.gateway.package` | `org.lucee.cfml.tasks` |
| `TASKS_EVENT_GATEWAY_TEMPLATE_PATH` | `tasks.event.gateway.template.path` | *(empty)* |
| `TASKS_EVENT_GATEWAY_TEMPLATE_PATH_RECURSIVE` | `tasks.event.gateway.template.path.recursive` | `true` |
| `TASKS_EVENT_GATEWAY_CHECKFORCHANGEINTERVAL` | `tasks.event.gateway.checkForChangeInterval` | `10` |
| `TASKS_EVENT_GATEWAY_CHECKFORCHANGENOMATCHINTERVAL` | `tasks.event.gateway.checkForChangeNoMatchInterval` | `60` |
| `TASKS_EVENT_GATEWAY_SETTINGLOCATION` | `tasks.event.gateway.settingLocation` | *(empty)* |
| `TASKS_EVENT_GATEWAY_CHECKFORCHANGESETTINGINTERVAL` | `tasks.event.gateway.checkForChangeSettingInterval` | `0` |
| `TASKS_EVENT_GATEWAY_LOG` | `tasks.event.gateway.log` | `application` |

### Runtime API (`sendGatewayMessage`)

Send messages to a running gateway instance using `sendGatewayMessage()` (first argument = gateway instance ID):

```cfc
// current gateway state
state = sendGatewayMessage("my-task", { action: "state" });

// JSON snapshot of tasks, threads, and settings
info = sendGatewayMessage("my-task", { action: "info" });
dump(deserializeJSON(info));

// pause / resume by full task name (component path)
sendGatewayMessage("my-task", { action: "pause", task: "core.tasks.MyWorker" });
sendGatewayMessage("my-task", { action: "resume", task: "core.tasks.MyWorker" });
```

When `settingLocation` is configured, pause state is persisted in cache and survives gateway restarts; with `checkForChangeSettingInterval` > 0, other servers pick up changes within that interval.

### Logging

The TEG uses four log levels:

- **debug** — regular task execution
- **info** — tasks added, modified, or removed
- **warn** — task execution failures, activator fallback
- **error** — unexpected gateway exceptions

Ensure the log named in `logName` exists in `.CFConfig.json` or the Administrator.

### Task configuration

Each task configures itself via `property` declarations on the base component `org.lucee.cfml.Task`:

```cfc
property name="concurrentThreadCount"               type="numeric" default=1;
property name="howLongToSleepBeforeTheCall"         type="numeric" default=0;
property name="howLongToSleepAfterTheCall"          type="numeric" default=0;
property name="howLongToSleepAfterTheCallWhenError" type="numeric" default=60000;
property name="howLongToWaitForTaskOnStop"          type="numeric" default=10000;
property name="forceStop"                           type="boolean" default=false;
```

| Property | Description |
|---|---|
| `concurrentThreadCount` | Number of parallel threads for this task |
| `howLongToSleepBeforeTheCall` | Milliseconds to sleep before each `invoke()` |
| `howLongToSleepAfterTheCall` | Milliseconds to sleep after a successful `invoke()` |
| `howLongToSleepAfterTheCallWhenError` | Milliseconds to sleep after an exception (prevents log spam) |
| `howLongToWaitForTaskOnStop` | Grace period when stopping the gateway before optional force-terminate |
| `forceStop` | Terminate the task thread if it does not stop within the grace period |

Full property documentation is in `source/components/org/lucee/cfml/Task.cfc`.

### Listener configuration

Each listener configures which tasks it applies to via `allow` and `deny` properties (comma-separated lists with `*` and `?` wildcards). Deny overrides allow.

```cfc
property name="allow" type="string" default="*";
property name="deny"  type="string" default="";
```

Full documentation is in `source/components/org/lucee/cfml/Listener.cfc`.

---

## Creating a Task

The TEG scans the component package from gateway configuration (e.g. `core.tasks` → `/core/tasks`). Any component extending `org.lucee.cfml.Task` is picked up and executed automatically. Changes to the CFC are detected on the next scan (see `checkForChangeInterval`).

```cfc
component extends="org.lucee.cfml.Task" {

    property name="howLongToSleepAfterTheCall" type="numeric" default=5000;

    public void function invoke(
        required string id,
        required numeric iterations,
        required numeric errors,
        numeric lastExecutionTime,
        date lastExecutionDate,
        struct lastError
    ) {
        // id = thread instance id; iterations/errors = lifetime counters for this instance
        systemOutput("Worker #id# iteration #iterations# at #now()#", 1, 1);
    }
}
```

All task properties inherit defaults from the abstract component and are optional.

## .cfm-based tasks

Tasks can also be plain `.cfm` templates — useful for reusing existing scheduled templates without rewriting them. They run as internal requests, so `Application.cfc` runs first.

Set `templatePath` in the gateway configuration. Each template must include task metadata in a comment block:

```cfm
<!---
@task                           "CFML Dummy Task"
@description                    "Example template-based task"
@concurrentThreadCount          1
@howLongToSleepBeforeTheCall    2000
@howLongToSleepAfterTheCall     2000
@howLongToSleepAfterTheCallWhenError 10000
@howLongToWaitForTaskOnStop     10000
@forceStop                      false
--->
```

Inside the template, the same arguments passed to `invoke()` are available in the `url` scope: `url.id`, `url.iterations`, `url.errors`, `url.lastExecutionTime`, `url.lastExecutionDate`, `url.lastError`.

---

## Creating a Listener

Listeners extend `org.lucee.cfml.Listener` and implement `onExecutionStart`, `onExecutionEnd`, and `onError`. They are discovered from the same package as tasks.

```cfc
component extends="org.lucee.cfml.Listener" {

    property name="allow" type="string" default="MyWorker,*Queue*";
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
        log text="Task #task# failed: #error.message#" type="error";
    }

    public void function onExecutionStart(/* same signature as onError minus error */) {}
    public void function onExecutionEnd(/* same signature as onError minus error */) {}
}
```

---

## Troubleshooting

| Symptom | Things to check |
|---|---|
| Gateway state stays `stopped` | Activator `active()` returns false; check gateway log for startup errors |
| Task not picked up | CFC extends `org.lucee.cfml.Task`; package matches `custom.package`; mapping/webroot resolves |
| Template task ignored | `@task` metadata present; file under `templatePath`; path reachable via internal request |
| Changes not applied | Lower `checkForChangeInterval`; confirm file timestamp changed |
| Pause not synced across servers | Same `settingLocation` cache on all nodes; `checkForChangeSettingInterval` > 0 |
| High CPU / log volume after errors | Increase `howLongToSleepAfterTheCallWhenError` on the task |

For more detail, see the [Tasks Event Gateway recipe](https://docs.lucee.org/recipes/task-event-gateway.html) in the Lucee documentation.
