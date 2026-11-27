# Architecture

This page explains how **Stryker (for Ruby)** is put together: the pipeline a run goes through, the two kinds of process that run its stages, the ports where it meets test frameworks, processes, configuration files, and reports, and the values and events that pass between the parts. Read it to see where a piece of code belongs and which way dependencies point. The terms are defined in [Loading and isolation](loading-and-isolation.md#terms).

**Stryker (for Ruby)** is a sibling of StrykerJS, Stryker.NET, and Stryker4s, not a plugin of any of them. It shares their concepts, their mutator names, the [mutation testing report schema](https://github.com/stryker-mutator/mutation-testing-elements/tree/master/packages/report-schema), the `mutation-testing-elements` HTML component, and the Stryker dashboard.

## The pipeline

A run goes through these stages, in order. Each stage takes values from the one before it and hands values to the next.

```mermaid
flowchart TB
  C["Configure"] --> F["Find files"]
  F --> P["Parse and find sites"]
  P --> I["Instrument"]
  I --> L["Load"]
  L --> D["Dry run"]
  D --> PL["Plan mutant runs"]
  PL --> R["Run each mutant in isolation"]
  R --> RE["Report"]
```

- **Configure.** A config source adapter reads `stryker.config.json` or `stryker.config.yml`, and `Configure.call` merges the file with the command line's options and the defaults, checks every option, and returns one `Config` value. [Configuration](../../configuration.md) lists the options, their defaults, and the checks.
- **Find files.** `SourceFiles` selects the files that the `mutate` patterns match, applying the patterns in order, as StrykerJS applies them, and gives each file's path from the project's root. [`mutate`](../../configuration.md#mutate) describes the patterns.
- **Parse and find sites.** Prism parses each file, and each mutator walks the tree and returns a `Mutant` for each change it makes: the mutator's name and a text edit on the source ([Mutators](mutators.md) specifies the catalog). The mutants of a run are numbered from 1, file after file, so each ID is unique in the run.
- **Instrument.** The instrumenter produces instrumented source for each file, with every mutant in the file behind a switch, and the pipeline writes it to a cache outside the project. [Mutant placement](mutant-placement.md) specifies where each switch goes and where each mutant's text comes from. A mutant whose plain mutant doesn't parse gets no switch, and its result has the status `CompileError`. A file with many mutants has the validity checks of its mutants spread over a pool of parse workers ([Parsing plain mutants](loading-and-isolation.md#parsing-plain-mutants)).
- **Load.** In each project process, the loader installs its `load_iseq` hook, and the test runner adapter loads the project's test helper and tests, which load the instrumented code through the hook. [Loading and isolation](loading-and-isolation.md#loading-instrumented-code) specifies the hook.
- **Dry run.** Every test runs once with no mutant active, in a child forked from the parent that loaded the project, and the switches record which tests reach which mutants. The dry run fails, and no mutant runs, when a test fails, when an instrumented file loaded without going through the hook, or when its tests take longer than `dryRunTimeoutMinutes`. `Isolation::ForkPerRun#dry_run` returns what it found as a `DryRunResult`. [The dry run](coverage.md#the-dry-run) explains where it runs and why, and [Coverage](coverage.md) specifies the hits and buckets.
- **Plan mutant runs.** From what a dry run of every test found, a `DryRunResult`, the plan gives each mutant the status `NoCoverage`, a static run, or a runtime run of the tests that reached it, with a time limit taken from the dry-run times of those tests. [The plan](coverage.md#the-plan) explains the rules and the time limit.
- **Run each mutant in isolation.** An isolation adapter runs each mutant run in a clean process: a child forked from a loaded parent for a runtime mutant on Linux and macOS, or a fresh process for a static mutant on every system. [Loading and isolation](loading-and-isolation.md#isolation) specifies it.
- **Report.** Each reporter receives every domain event of the run, and one that needs every result builds its output when the run completes ([Values and events](#values-and-events)).

`Stryker::Pipeline` runs every stage after Configure, and owns what a run starts for exactly as long as the run lasts: the cache of instrumented source, and two isolation adapters, one for the dry run and the runtime mutants and one for the static mutants. However the run ends (it finishes, a stage raises, or INT or TERM arrives), the cache is gone and every process the adapters started has ended before the command exits, with status 128 plus the signal's number after a signal. The pipeline owns this, and not each adapter or stage, so that no stage can leave a project process running with a mutant active, or files in the user's temporary folder, because it failed or was interrupted at the wrong moment. A second signal during the cleanup ends the cleanup at once, as a second signal ends a StrykerJS run at once. The fork parent still ends its children and itself then, because the orchestrator's exit closes the parent's standard input.

The pipeline holds no code for a system or a report format. `CLI::MutationTesting`, which `stryker run` hands the checked config to, builds the isolation adapters and the reporters and hands them to it: `Isolation::ForkPerRun` for the dry run and the runtime mutants and `Isolation::FreshProcesses` for the static mutants where Ruby has `fork`, and one reporter for each name in the `reporters` option. Where Ruby has no `fork`, as on Windows, it stops the run before any file is read, because a dry run and runtime mutants without `fork` aren't built ([#37](https://github.com/setdef/stryker_for_ruby/issues/37)).

## Two kinds of process

A run has two kinds of process. The orchestrator is the process that `stryker run` starts, and it runs Configure, Find files, Parse and find sites, Instrument, Plan mutant runs, and Report. A project process loads the project's code, and it runs Load and the dry run. [Loading and isolation](loading-and-isolation.md#two-kinds-of-process) specifies both kinds.

```mermaid
flowchart LR
  subgraph O["Orchestrator: loads Prism and refract"]
    direction TB
    S1["Configure, parse and find sites, instrument, plan"]
  end
  CA[("Cache of instrumented source, in a temporary directory")]
  subgraph PP["Project processes: load only the runtime"]
    direction TB
    S5["Load, through the hook"]
  end
  S1 -- writes --> CA
  CA -- read by the hook --> S5
```

Prism and refract load only in the orchestrator, and only when `stryker run` goes on to configure a run, so `stryker --version` and `stryker help` don't load them. A project process loads only the runtime, which uses nothing outside the standard library ([ADR 0003](../decisions/0003-the-processes-that-load-the-projects-code-load-only-stryker-for-rubys-runtime-which-depends-on-nothing-outside-the-standard-library.md)).

## Ports and adapters

**Stryker (for Ruby)** follows the ports-and-adapters architecture, also called hexagonal architecture. The core, which is every stage after Configure and the values they pass, holds no code for a particular test framework, operating system, file format, or report format. Where it needs one, it declares a port: an interface named for what the core needs, such as "run these tests". An adapter implements a port for one framework, system, or format. Dependencies point inward: adapters depend on the core, and the core's code never refers to an adapter.

```mermaid
flowchart TB
  subgraph core["Core"]
    direction TB
    PIPE["Pipeline: parse, instrument, load, plan"]
    VAL["Values: Config, Mutant, Location, Test, TestResult, DryRunResult, MutantRun, MutantResult"]
    EVT["Events: DryRunCompleted, PlanReady, MutantTested, RunCompleted"]
    subgraph ports["Ports: RBS interfaces only"]
      TR["_TestRunner"]
      ISO["_Isolation"]
      DRI["_DryRunIsolation"]
      REPP["_Reporter"]
      CS["_ConfigSource"]
    end
  end
  subgraph adapters["Adapters in the gem"]
    MT["TestRunners::MinitestRunner"]
    JC["ConfigSources::JsonFile"]
    YC["ConfigSources::YamlFile"]
    FP["Isolation::ForkPerRun"]
    FR["Isolation::FreshProcesses"]
    JR["Reporters::JsonReport"]
    CX["Reporters::ClearText"]
  end
  CT["stryker/testing: contract tests"]
  PIPE --> TR & CS & ISO & DRI & REPP
  MT -. implements .-> TR
  JC & YC -. implements .-> CS
  FP -. implements .-> DRI
  FR -. implements .-> ISO
  JR & CX -. implements .-> REPP
  CT -. verifies .-> MT & JC & YC
```

Solid arrows are calls. Dotted arrows show which classes implement a port, and which tests check them.

Adapter names end in a word such as `Runner` or `File` because inside a Stryker namespace, Ruby would resolve `Minitest`, `JSON`, or `YAML` to such an adapter instead of the top-level library.

### The ports

Ruby has no interface keyword, so the ports exist only as RBS interfaces in `sig/`. Ruby checks nothing about them: any object with the right methods works. Steep checks each adapter's method signatures against them, and the contract tests check each adapter's behavior.

```rbs
module Stryker
  type event = Events::DryRunCompleted | Events::PlanReady | Events::MutantTested | Events::RunCompleted

  # Lists and runs the project's tests in one framework.
  interface _TestRunner
    # Loads the project's test helper and test files, and returns every test
    # they define, without running any. Every process that loads the same
    # files gets the same tests, with the same IDs.
    def load_tests: () -> Array[Test]

    # Runs the tests with these IDs, in order, one at a time. Calls
    # observer.test_started before each test and observer.test_finished
    # after it. Stops after the first failing test when bail is true. Raises
    # ArgumentError, before it runs any test, for an ID it doesn't know.
    def run: (Array[String] test_ids, bail: bool, observer: _TestObserver) -> Array[TestResult]
  end

  # Hears when each test starts and finishes. The hit recorder is one.
  interface _TestObserver
    def test_started: (Test test) -> void
    def test_finished: (TestResult result) -> void
  end

  # Runs mutant runs, each in a process that ran no test before it.
  interface _Isolation
    # Starts what the runs need: the loaded parent, or the pool.
    def start: (Config config) -> void

    # Runs every run, up to config.concurrency at a time, and yields each
    # result as it arrives.
    def run_all: (Array[MutantRun] runs) { (MutantResult result) -> void } -> void

    # Ends every process the adapter started.
    def stop: () -> void
  end

  # An isolation adapter that also runs the dry run, between start and stop.
  interface _DryRunIsolation
    include _Isolation

    # Runs every test once with no mutant active, and returns what it found.
    def dry_run: (Config config) -> DryRunResult
  end

  # Receives each domain event of a run, in the order the run publishes them.
  interface _Reporter
    def call: (event event) -> void
  end

  # A value that a JSON document can hold.
  type json_value = String | Integer | Float | bool | nil | Array[json_value] | Hash[String, json_value]

  # Reads options from one kind of configuration file.
  interface _ConfigSource
    # Returns the file's options as nested hashes, keyed by the option names
    # in the file, or nil when the file doesn't exist. Raises ConfigError
    # when the file can't be read or parsed, or holds something other than an
    # object.
    def read: () -> Hash[String, json_value]?
  end
end
```

A port says what the core needs, and nothing about how an adapter does it:

- **`_TestRunner`** lists and runs the project's tests in one framework. Its adapter is `TestRunners::MinitestRunner`, which [Test runners](test-runners.md) specifies.
- **`_Isolation`** runs mutant runs, each in a process that ran no test before it. Its adapters are `Isolation::ForkPerRun` and `Isolation::FreshProcesses`, which [Loading and isolation](loading-and-isolation.md#isolation) specifies.
- **`_DryRunIsolation`** is an `_Isolation` that also runs the dry run, in the kind of process that its mutant runs start from. Its adapter is `Isolation::ForkPerRun`, whose dry run is a child of the parent that forks every runtime mutant's run ([The dry run](coverage.md#the-dry-run)).
- **`_Reporter`** receives each domain event of a run. Its adapters are `Reporters::JsonReport` and `Reporters::ClearText`, which [Configuration](../../configuration.md#reporters) says how to use. A reporter that needs every result builds its output when it receives `Events::RunCompleted`.
- **`_ConfigSource`** reads the options of one kind of configuration file. Its adapters are `ConfigSources::JsonFile` and `ConfigSources::YamlFile`, which [Configuration](../../configuration.md#the-configuration-file) says how to use.

### Contract tests

`require "stryker/testing"` loads one Minitest module for each of these ports that has an adapter: `Stryker::Testing::TestRunnerContract`, `ConfigSourceContract`, and `ReporterContract`. Each holds the tests that every adapter of its port must pass, and the gem's adapters pass them, so an adapter written outside the gem is held to the same behavior. The RBS documentation of [`Stryker::Testing`](../../../sig/stryker/testing.rbs) says how to use them.

## Values and events

Every value that passes between stages is a `Data.define` class: immutable and compared by value. Each one's fields are in its RBS documentation, which the table links. The ones that cross a pipe between processes also convert to and from JSON, as [`Stryker::JsonValue`](../../../sig/stryker/json_value.rbs) says. A project process loads them, so they use only the standard library ([ADR 0003](../decisions/0003-the-processes-that-load-the-projects-code-load-only-stryker-for-rubys-runtime-which-depends-on-nothing-outside-the-standard-library.md)).

| Value | What it carries |
| - | - |
| [`Config`](../../../sig/stryker/config.rbs) | The options of the run, after the file and the command line are merged, from Configure to every stage after it. |
| [`Location`](../../../sig/stryker/location.rbs) | The stretch of a file that a mutant changes, as the report schema gives it. |
| [`Mutant`](../../../sig/stryker/mutant.rbs) | One change to a file: its ID, its mutator's name, its text edit, and, for some mutators, a description of the change, from Parse and find sites to Instrument. |
| [`Test`](../../../sig/stryker/test.rbs) | One test of the project, from the test runner adapter to the stages that run tests. |
| [`TestResult`](../../../sig/stryker/test_result.rbs) | What happened when one test ran, from the test runner adapter to the stages that judge it. |
| [`DryRunResult`](../../../sig/stryker/dry_run_result.rbs) | What a dry run of every test found, which says which tests reach which mutants. |
| [`MutantRun`](../../../sig/stryker/mutant_run.rbs) | One run of a chosen set of tests with one mutant active. |
| [`MutantResult`](../../../sig/stryker/mutant_result.rbs) | What a run found out about one mutant, in the terms of the report. |

A round trip through JSON gives an equal value. A project's files can be in any encoding, so each field that holds source text or a path crosses as its bytes and its encoding's name, as the parse pool sends a file's bytes ([Parsing plain mutants](loading-and-isolation.md#what-crosses-the-pipes)). A field that holds a message for a reader crosses as valid UTF-8, with each byte that isn't valid replaced by U+FFFD, because a test can fail with such a message, and JSON holds only Unicode text. Each value's RBS documentation says which of its fields are which:

| Fields | How they cross JSON |
| - | - |
| `Mutant#file`, `Mutant#replacement`, `Test#file`, and each path in `DryRunResult#files_loaded_in_tests` | Bytes and encoding name |
| `TestResult#failure_message`, `MutantResult#status_reason`, and `Mutant#description` | Valid UTF-8 |
| Every other String, such as IDs, names, and the keys of `DryRunResult#buckets` | Valid UTF-8 |

A run publishes domain events, each also a `Data.define` value ([`Stryker::Events`](../../../sig/stryker/events.rbs)), and the core hands each event to every reporter:

| Event | Published when |
| - | - |
| `Events::DryRunCompleted` | the dry run passes |
| `Events::PlanReady` | every mutant has a status or a run |
| `Events::MutantTested` | a result is collected |
| `Events::RunCompleted` | the last result is collected |

Stages never call a reporter directly, so adding a reporter changes no stage.

## Where each responsibility lives

| Responsibility | Lives in |
| - | - |
| Reading the configuration file | the config source adapter for its format |
| Merging command-line options and checking every option's name and type | Configure |
| Keeping every path inside the project's root | Configure, for the `mutate` patterns, and every adapter that builds a path |
| Selecting the files to mutate | Find files |
| Deciding what each mutant changes | the mutator that finds its site |
| Giving each mutant of a run its ID | Parse and find sites |
| Producing instrumented source, and the `CompileError` result of each mutant that isn't valid Ruby | the instrumenter |
| Keeping the cache and every process of a run for exactly as long as the run lasts, sending each run to the adapter for its kind of mutant, and handing each event to every reporter | the pipeline |
| Choosing the isolation adapters for the system, and the reporters by name | `CLI::MutationTesting` |
| Serving instrumented source to Ruby, and checking that every loaded instrumented file came through the hook | the loader |
| Listing tests, running a chosen set, and marking where each test starts and ends | the test runner adapter for its framework ([Test runners](test-runners.md)) |
| Recording which tests reach which mutants | the hit recorder in the Stryker runtime |
| Choosing each mutant's tests, kind of run, and time limit | the plan |

## Why this isn't an information system

Domain-driven design's tactical patterns, such as repositories, aggregates, and the unit of work, are for information systems: software that keeps records for a long time, lets many people change them at once, and has to keep each change consistent with the rest. A repository gives the domain a collection of stored records, an aggregate is the boundary inside which a change must stay consistent, and a unit of work makes several changes commit or fail together.

**Stryker (for Ruby)** keeps no records. A run is a batch computation: it reads the source, the tests, and the configuration, computes results, and writes reports once at the end. Nothing it holds outlives the run, and nobody changes its data while it runs. So there is nothing to store and query, no concurrent change to keep consistent, and no transaction to commit, so those three patterns don't apply. What the design takes from domain-driven design is what does apply: a vocabulary shared with the other Stryker ports, immutable values, domain events, and ports at the edges where the outside world varies.

## Related

- [Loading and isolation](loading-and-isolation.md), for the two kinds of process, the cache, and the hook.
- [Mutant placement](mutant-placement.md), for how the instrumenter places each switch.
- [Coverage](coverage.md), for how the switches record which tests reach which mutants.
- [Test runners](test-runners.md), for how each test runner adapter lists and runs a project's tests.
- [ADR 0001](../decisions/0001-mutants-are-compiled-into-the-code-once-and-switched-on-at-run-time.md), for why mutants are compiled into the code once and switched on at run time.
- [ADR 0002](../decisions/0002-every-mutant-runs-in-a-clean-process.md), for why every mutant runs in a clean process.
- [ADR 0003](../decisions/0003-the-processes-that-load-the-projects-code-load-only-stryker-for-rubys-runtime-which-depends-on-nothing-outside-the-standard-library.md), for why the processes that load the project's code load only the runtime.
