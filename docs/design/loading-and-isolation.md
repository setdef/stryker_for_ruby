# Loading and isolation

This page specifies how instrumented code gets into a Ruby process, and how each mutant run gets a clean process to run in. It covers the two kinds of process in a run, the bundle they run in, what runs in a project process, the cache that holds instrumented source, the loader's hook, how the hook stays ahead of Bootsnap, the check that the hook saw every instrumented file, how results reach the orchestrator, forking on Linux and macOS, the process pool on Windows, and static mutants. The reasons for loading through the hook are in [ADR 0001](../decisions/0001-mutants-are-compiled-into-the-code-once-and-switched-on-at-run-time.md), and the reasons for running every mutant in a clean process are in [ADR 0002](../decisions/0002-every-mutant-runs-in-a-clean-process.md). Where loading fits in the whole run is in [the architecture](architecture.md).

## Terms

- **Instrumented file:** a project file matched by the `mutate` option. The instrumenter produces instrumented source for it, which holds every mutant in the file behind a switch.
- **Active mutant:** the one mutant whose switch takes the mutated branch. At most one mutant is active in a process. With none active, the instrumented code behaves as the original.
- **Runtime mutant:** a mutant whose switch runs while a test runs. Setting it active at any time before the test starts is enough.
- **Static mutant:** a mutant whose switch runs only while its file loads, such as one in a constant's value or a class body. It takes effect only when it is active before the file loads. [Coverage](coverage.md) says how **Stryker (for Ruby)** tells the two apart.
- **Mutant run:** one run of a chosen set of tests with one mutant active.
- **Orchestrator:** the process that `stryker run` starts.
- **Project process:** a process that loads the project's code.

## Two kinds of process

The orchestrator never loads the project's code, and a project process never instruments, plans, or reports:

| Process | What it does | The code of **Stryker (for Ruby)** that it loads |
| - | - | - |
| The orchestrator | Reads the configuration, finds and parses the files, instruments them, writes the cache, starts the project processes, plans the mutant runs, collects the results, and writes the reports. | The code that instruments, plans, and reports, with Prism and refract. |
| A project process: the parent that forks, each child forked from it, each process in the Windows pool, and each fresh process for a static mutant | Installs the hook, loads the project's code and tests, and runs tests. | Only its runtime, which uses nothing outside the standard library. |

Prism and refract load only in the orchestrator. The reasons are in [ADR 0003](../decisions/0003-the-processes-that-load-the-projects-code-load-only-stryker-for-rubys-runtime-which-depends-on-nothing-outside-the-standard-library.md).

### The bundle

The orchestrator runs inside the project's bundle, with the gem in the project's Gemfile, so Prism and refract resolve against the project's locked gems. The orchestrator starts every project process with the same bundle environment.

### What runs in a project process

The runtime holds the hook, the switch, and the hit recorder. It also holds the test runner adapters, the code that writes results to a pipe, and the part of each isolation adapter that runs in a project process: the fork parent's loop, and a pool process's wait for its run. All of it uses nothing outside the standard library. The rest of each isolation adapter runs in the orchestrator, which starts the project processes, reads their results, and enforces the time limits that [How results reach the orchestrator](#how-results-reach-the-orchestrator) assigns to it.

### The cache

The orchestrator writes the instrumented source of every instrumented file to a cache outside the project: a temporary directory that it makes with `Dir.mktmpdir`, and deletes when the run ends. A project process reads instrumented source only from that cache. Nothing is written into the project.

## Loading instrumented code

### The `load_iseq` hook

Ruby compiles every file it loads from disk, whether through `require`, `require_relative`, `load`, or an autoload such as Zeitwerk's. Before it compiles one, CRuby calls `RubyVM::InstructionSequence.load_iseq(path)`, if that method exists. When the method returns an instruction sequence, Ruby runs it in place of compiling the file. When it returns `nil`, Ruby compiles the file as usual.

The loader prepends a module to `RubyVM::InstructionSequence.singleton_class` that defines `load_iseq`. For each call, the module does one of two things:

- When `path` is an instrumented file's path, it reads that file's instrumented source from the cache, compiles it with `RubyVM::InstructionSequence.compile`, giving the original `path` as both the file name and the path, records that it served `path`, and returns the result.
- For any other file, it calls `super` when a module further down the chain defines `load_iseq`, and returns `nil` otherwise. Ruby has no default `load_iseq`, so a bare `super` raises `NoMethodError` when nothing else has prepended one.

In both cases, when a test is running, the module records `path` as a file whose load began during that test. [Coverage](coverage.md#static-hits-inside-a-test) says what the recorder does with it.

Because Ruby still resolves the file and still compiles the code under its original path, `__FILE__`, `__dir__`, `require_relative`, `$LOADED_FEATURES`, and the file names in backtraces all show the original file's path. Zeitwerk works unchanged: in a probe project that Zeitwerk loads, every instrumented file came through the hook.

The loader installs the hook before any of the project's code loads, in every project process: the parent that forks, each fresh process, and each process in the Windows pool.

`load_iseq` is part of CRuby's `RubyVM` API. JRuby and TruffleRuby don't call it, so **Stryker (for Ruby)** runs on CRuby only.

### Keeping the hook ahead of Bootsnap

Bootsnap, for its compile cache, prepends a module with a `load_iseq` method to the same singleton class. Of two prepended modules, Ruby calls the one prepended last first, and Bootsnap's `load_iseq` doesn't call `super`. So a Bootsnap module prepended after the hook would serve the original file, and every mutant in it would have no effect, with no error raised.

A new Rails 8.1 app sets up Bootsnap from its test helper, after the hook: `test/test_helper.rb` requires `config/environment`, which requires `config/application`, which requires `config/boot`, and `config/boot.rb` runs `require "bootsnap/setup"`. Turning Bootsnap's compile cache off doesn't help. Requiring `bootsnap` calls `Bootsnap::CompileCache::ISeq.install!(nil)`, which prepends the module even when `DISABLE_BOOTSNAP` or `DISABLE_BOOTSNAP_COMPILE_CACHE` is set, or when the app calls `Bootsnap.setup(compile_cache_iseq: false)`. With no cache directory, the module's `load_iseq` compiles the original file, and still doesn't call `super`.

So the loader keeps the hook in front. When it installs the hook, before any of the project's code loads, it also overrides `prepend` on `RubyVM::InstructionSequence.singleton_class`. Whenever a module that defines `load_iseq` is prepended after the hook, the override prepends a new copy of the hook module in front of it. The copy is new because Ruby doesn't move a module that is already among the ancestors, so prepending the first hook module again would change nothing.

Bootsnap prepends its module twice, so two copies of the hook stack in front of it. Both behave the same: for an instrumented file, the front copy serves the instrumented source; for any other file, each copy calls `super`, and Bootsnap serves the file from its cache as usual. The override covers any library that prepends `load_iseq` after the hook, not only Bootsnap.

### The loading check

The loading check catches an instrumented file that loaded without going through the hook, whatever the cause. The dry run, the first run of the whole suite with no mutant active, ends with it. For every instrumented file that appears in `$LOADED_FEATURES`, the loader confirms that the hook served it. When any loaded instrumented file didn't come through the hook, the dry run fails, no mutant runs, and the error lists each such file. When a module that defines `load_iseq` sits ahead of the hook in the singleton class's ancestors, the error message gives that module's name, which is Bootsnap's `Bootsnap::CompileCache::ISeq::InstructionSequenceMixin` when Bootsnap is the cause.

An instrumented file that no test loaded isn't an error: no test reaches its mutants, and the plan reports them as having no coverage.

### Paths on Windows

The loader compares each `path` it receives with the list of instrumented files. On Windows, Ruby can pass the same file with a different spelling: a lowercase drive letter, other letter case in the directory names, or backslashes. Before comparing, the loader normalizes both sides: it replaces each `\` with `/` and folds letter case.

> [!WARNING]
> Without that normalization, the hook doesn't recognize a file whose path is spelled differently, and the file loads uninstrumented with no error. A probe that put the project's `lib` folder on `$LOAD_PATH` with its letter case swapped, or with a lowercase drive letter, loaded every file uninstrumented. The loading check compares normalized paths too, so it catches a file that the hook missed this way.

### Approaches that don't work

Two other ways to load instrumented code look simpler. Probes on Ruby 3.3, 3.4, 4.0, and 4.1-dev found faults in both.

**A sandbox copy first on `$LOAD_PATH`.** Writing the instrumented files to a copy of the project and putting the copy's `lib` first on `$LOAD_PATH` does make the mutants take effect. But `__FILE__`, `__dir__`, `$LOADED_FEATURES`, and backtraces then name the sandbox instead of the project, so a test that checks a path sees the sandbox's. Bootsnap's cache also keys on a file's size and modification time in whole seconds, so a rewrite of the same size within the same second loads the old code from the cache.

**Hooks on `require`, `require_relative`, and `load`.** Prepending to `Kernel` needs all three hooks; with `require` alone, files loaded by `require_relative` stay uninstrumented. On Ruby 3.4 and later, in a project that Zeitwerk loads, hooks installed before Bootsnap fail with `NoMethodError: super: no superclass method 'require'`. On Windows, a file required by two spellings of its path loads twice.

## Isolation

Every mutant run happens in a process that has run no test before it, and that process ends when the run does. Nothing is reused for a second run. The isolation adapter that does this depends on the system and on the kind of mutant:

| Mutant | Linux and macOS | Windows |
| - | - | - |
| Runtime | A child forked from a loaded parent | A process from the pool |
| Static | A fresh process with the mutant ID in its environment | The same |

### How results reach the orchestrator

Every result travels over pipes, one JSON object per line. Each process that reads one parses it with `JSON.parse` and never with `Marshal.load`, because the process that wrote it ran the project's tests.

| Run | Who writes the result | Who reads it | Who enforces the time limit |
| - | - | - | - |
| Forked child | The child, to its fork parent, over a pipe of its own | The fork parent, which relays it to the orchestrator over the parent's own pipe | The fork parent |
| Windows pool process | The pool process, directly to the orchestrator | The orchestrator | The orchestrator |
| Fresh process for a static mutant | The fresh process, directly to the orchestrator | The orchestrator | The orchestrator |

The fork parent kills a child that runs past its time limit, and relays the timeout to the orchestrator as it relays any other result. The orchestrator kills a pool process or a fresh process that runs past its time limit.

### Forking on Linux and macOS

The parent process installs the hook, and then the test runner adapter loads the project's test helper and test files, which load the instrumented code. The parent runs no test, so every child starts from the same untouched state. Hits recorded while the parent loads are in its static bucket (see [Coverage](coverage.md)), and every child inherits them.

The dry run is itself a forked child, with no mutant active.

For each runtime mutant run, the parent:

1. opens a pipe of its own for the child and forks;
2. in the child, closes the read end, sets the active mutant, runs the run's tests through the test runner adapter, stopping at the first failure, writes the result to the pipe, and ends with `exit!`;
3. in the parent, reads the result, relays it to the orchestrator over the parent's own pipe, and waits for the child.

The parent keeps up to `concurrency` children running at once. When a child runs past the run's time limit, the parent kills it, and the run's result is a timeout, which the parent relays like any other result.

> [!WARNING]
> The child must end with `exit!`, never `exit`. A forked child inherits the parent's `at_exit` handlers, and `exit` runs them. `minitest/autorun` registers one that runs the test suite, so a child that calls `exit` runs every test again with the mutant still active.

`exit!` also skips flushing Ruby's write buffers. A pipe's write end from `IO.pipe` is in sync mode, so a write reaches the pipe at once and survives `exit!`. A child must not turn sync mode off on it, or its result is lost.

A fork costs about 0.6 ms on Linux from a parent of about 15 MB, and about 2 ms on macOS from a parent that has loaded a gem's test suite ([#4](https://github.com/setdef/stryker_for_ruby/issues/4)). From a parent of about 750 MB, it costs about 9 to 19 ms on Linux.

### The process pool on Windows

Windows has no `fork`: `Process.respond_to?(:fork)` is `false`, and `Process.fork` raises `NotImplementedError`. So each runtime mutant run gets a fresh `ruby` process instead, from a pool the orchestrator starts ahead of time.

Each process in the pool installs the hook, loads the test helper and test files through the test runner adapter, and then waits for one run on a pipe. When it receives a mutant ID and the run's test IDs, it sets the active mutant, runs the tests, stopping at the first failure, writes the result to a pipe that the orchestrator reads, and exits. The orchestrator enforces the run's time limit, killing a process that runs past it. It keeps `concurrency` processes in the pool, starting a new one as each exits, so a process loads the project while others run their tests.

A pool process loads the code before it learns its mutant, so the pool runs runtime mutants only.

A fresh process is expensive on Windows. On one probe machine, `ruby -e 1` took about 130 ms, of which about 110 ms was RubyGems: `ruby --disable-gems -e 1` took about 17 ms. Starting a process, loading three instrumented files, and running one Minitest test took about 285 ms. [#4](https://github.com/setdef/stryker_for_ruby/issues/4) gives 412 ms and 1,035 ms for the start of a process for two real gems' test suites.

### Static mutants on every system

A static mutant's switch runs once, while its file loads. Setting the mutant active afterwards changes nothing, because the switch never runs again. A probe set a static mutant in a constant's value active after load, and the constant kept its original value.

So every static mutant run gets a fresh process, on every system, with the mutant ID in the `STRYKER_ACTIVE_MUTANT` environment variable before the process starts. The fresh process writes its result directly to the orchestrator, which enforces the run's time limit. The runtime reads that variable when it loads, before any of the project's code, so the switch takes the mutated branch while the file loads. The run includes every test, because a value set at load time can reach any test.

### A file first loaded inside a test

A file that the project first requires inside a test, rather than from the test helper or another file loaded before the tests, loads during that test. Its load-time code runs during that test, so its switches would record their hits in that test's bucket instead of the static bucket. A probe that required such a file in one test and used its constant in a second test recorded the constant's mutant as reached by the first test only.

The hook records the path of each file whose load begins during a test. A hit that lands inside a test counts as static when the stack holds the top-level frame of one of those files, so the mutant is planned as a static mutant and its run includes every test. [Static hits inside a test](coverage.md#static-hits-inside-a-test) specifies the rule.

One case isn't handled: a hit made on another thread or a fiber while such a file loads. Its stack has no top-level frame, so the hit stays in the test's bucket, and the mutant is planned as a runtime mutant that runs only the tests that recorded it. A test that depends on the file's load-time values but didn't record the hit isn't in the run, so a mutant that this test would have killed can be reported as surviving. The dry run reports every file first loaded during a test, so you can see where this applies.

## What this design doesn't do

- It doesn't reuse a process for a second run, on any system.
- It doesn't run on Ruby implementations other than CRuby.
- It doesn't turn Bootsnap off or change its settings. Files that aren't instrumented still load through Bootsnap's cache.
- It doesn't load Prism or refract in a project process.
- It doesn't attribute a hit made on another thread or a fiber to a file that loads inside a test.
- It doesn't write instrumented source into the project.
