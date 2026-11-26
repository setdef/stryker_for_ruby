# Loading and isolation

This page specifies how instrumented code gets into a Ruby process, and how each mutant run gets a clean process to run in. It covers the two kinds of process in a run, the bundle they run in, what runs in a project process, the cache that holds instrumented source, the loader's hook, how the hook stays ahead of Bootsnap, the check that the hook saw every instrumented file, the pool of workers that parses the plain mutants of a large file, the entry point of a project process, the messages that cross each pipe, how a run's outcome becomes a status, time limits and kills, static mutants, and how the active mutant, the hook, and the lookup tables work in a Ractor. The reasons for loading through the hook are in [ADR 0001](../decisions/0001-mutants-are-compiled-into-the-code-once-and-switched-on-at-run-time.md), and the reasons for running every mutant in a clean process are in [ADR 0002](../decisions/0002-every-mutant-runs-in-a-clean-process.md). Where loading fits in the whole run is in [the architecture](architecture.md).

## Terms

- **Instrumented file:** a project file matched by the `mutate` option. The instrumenter produces instrumented source for it, which holds every mutant in the file behind a switch.
- **Active mutant:** the one mutant whose switch takes the mutated branch. At most one mutant is active in a process. With none active, the instrumented code behaves as the original.
- **Runtime mutant:** a mutant whose switch runs while a test runs. Setting it active at any time before the test starts is enough.
- **Static mutant:** a mutant whose switch runs only while its file loads, such as one in a constant's value or a class body. It takes effect only when it is active before the file loads. [Coverage](coverage.md) says how **Stryker (for Ruby)** tells the two apart.
- **Mutant run:** one run of a chosen set of tests with one mutant active.
- **Orchestrator:** the process that `stryker run` starts.
- **Project process:** a process that loads the project's code.
- **Parse worker:** a fresh `ruby` process that the orchestrator starts to parse plain mutants. It loads Prism and not the project's code, so it is not a project process.

## Two kinds of process

The orchestrator never loads the project's code, and a project process never instruments, plans, or reports:

| Process | What it does | The code of **Stryker (for Ruby)** that it loads |
| - | - | - |
| The orchestrator | Reads the configuration, parses the files, instruments them (starting parse workers for a file with many mutants), writes the cache, starts the project processes, and judges each run from what they write. | The code that instruments, with Prism and refract, and the part of each isolation adapter that starts and judges the runs. |
| A project process: each fresh process for a static mutant | Installs the hook, loads the project's code and tests, and runs tests. | Only its runtime, which uses nothing outside the standard library. |

Prism and refract load in the orchestrator, and never in a project process. A parse worker, which isn't a project process, loads Prism too ([Parsing plain mutants](#parsing-plain-mutants)). The reasons are in [ADR 0003](../decisions/0003-the-processes-that-load-the-projects-code-load-only-stryker-for-rubys-runtime-which-depends-on-nothing-outside-the-standard-library.md).

### The bundle

The orchestrator runs inside the project's bundle, with the gem in the project's Gemfile, so Prism and refract resolve against the project's locked gems. The orchestrator starts every project process with the same bundle environment.

### What runs in a project process

The runtime holds the hook, the switch, and the hit recorder, and the collector Ractor of every process that records hits, which starts when the project makes its first Ractor ([Ractors](coverage.md#ractors)). A project that makes no Ractor gets none from the runtime. It also holds the test runner adapters, the entry point of a project process ([The entry point](#the-entry-point)), the code that writes each test's result as the test finishes, and the part of the isolation adapter that runs in a project process: a fresh process's run. All of it uses nothing outside the standard library. The rest of the isolation adapter runs in the orchestrator, which starts the project processes, reads their messages, judges each run, and enforces the time limits that [Time limits and kills](#time-limits-and-kills) assigns to it.

### The cache

The orchestrator writes the instrumented source of every instrumented file to a cache outside the project: a temporary directory that it makes with `Dir.mktmpdir`, and deletes when the run ends. A project process reads instrumented source only from that cache. Nothing is written into the project.

The directory holds two kinds of file:

| File | What it holds |
| - | - |
| `0.rb`, `1.rb`, and so on | One instrumented file's instrumented source each, byte for byte, written in binary mode so that no system changes its line endings. |
| `index` | The instrumented files' paths, in the same order, with a NUL byte between two paths and none at the end. |

The index holds each path as its bytes, whatever encoding Ruby tagged the path with, because paths in one run can come in several encodings. No path holds a NUL byte, so the index needs no escaping, and the runtime reads it with `String#split`, so a project process loads no format library, not even the `json` default gem, whose version the project's bundle would choose. Each file's name comes from its place in the index, so no name that the project chose becomes part of a path in the cache.

When the loader is installed, it reads the index into a lookup table from each instrumented file's keys to that file's place in the cache. It reads instrumented source only when it serves a file. Each instrumented file has two keys: one for its path, and one for its real path, with every symbolic link and `..` resolved. In one process, Ruby gives the hook the real path of a file it finds through `$LOAD_PATH` or `require_relative`, and the path as written for a `require` of an absolute path, so a table with one of the two misses some loads of a project under a symbolic link, such as a temporary folder under `/var` on macOS. The table also holds the base name of each key, with letter case folded, which the hook uses to decide when to resolve a real path ([The `load_iseq` hook](#the-load_iseq-hook)). The table is shareable ([Lookup tables](#lookup-tables)).

## Parsing plain mutants

The instrumenter checks that each mutant is valid Ruby by parsing its [plain mutant](mutant-placement.md#the-plain-mutant), the original file with the mutant's edit made. A file with many mutants costs one whole-file parse for each of them. The orchestrator spreads those parses over a pool of parse workers when a file has enough of them to pay for the workers' start.

A parse worker is a fresh `ruby` process. The pool starts each one from an array of arguments: the running Ruby, `-r` with the path of the worker's file, and `-e Stryker::Instrumenter::ParseWorker.serve`. The worker inherits the orchestrator's environment, so Prism resolves against the project's locked gems, as it does in the orchestrator. A worker loads Prism and the standard library's JSON, and loads neither refract nor the project's code. The pool runs at most `concurrency` workers, and the instrumenter's `concurrency` argument is the number of processors by default.

A fresh process is the one way that runs the same on Linux, macOS, and Windows. A forked worker would need a second way for Windows, which has no `fork`, and forking is no faster than fresh processes at 8 workers. Ractors scale no further than 4 workers and print Ruby's experimental warning ([#16](https://github.com/setdef/stryker_for_ruby/issues/16)).

### What crosses the pipes

Jobs and results cross pipes as JSON lines, as the isolation adapters' messages do ([The protocol](#the-protocol)). The reading side parses each line with `JSON.parse` and never with `Marshal.load`. A line holds the bytes of a file or of a replacement in Base64, because JSON holds only Unicode text and a project's file may be in any encoding.

The orchestrator writes a worker one line with a file's source, and then one line for each plain mutant, which holds its patches: the changes to the original source that make the plain mutant. A patch is the offsets of the bytes it replaces and the text that replaces them, and the offsets are the original source's. The patches of a plain mutant take out the heredoc bodies that it leaves out, make the mutant's edit, and put the parentheses around the wrapped node. A plain mutant's text is as large as the file, so the file goes once to each worker and each plain mutant goes as a few patches. The worker makes the text from the source and the patches with the code that the orchestrator uses for the same job, parses it with Prism with the syntax of the running Ruby, and writes one line, `{"valid":true}` or `{"valid":false}`. A worker writes nothing for a source.

The pool gives each worker one plain mutant in a round, and the plain mutant of the next round before it reads this round's verdicts, so that a worker parses while the pool reads the verdict of another. A pipe holds at most two plain mutants' lines for a worker. A round ends when its slowest worker does, which costs little because every plain mutant of a file takes about as long to parse as the others.

### How many workers

A worker takes about 0.1 seconds to start on Linux ([#16](https://github.com/setdef/stryker_for_ruby/issues/16)) and about 0.25 seconds on Windows, where starting several workers takes the sum of their starts: a pool of 4 workers took 1 to 1.5 seconds to start, and a pool of 32 took 5 to 9 seconds. One process parses 36 million bytes per second on Windows, and 40 to 70 million on Linux. The work of a file is its size in bytes times its number of plain mutants, which is the number of bytes that Prism parses for it.

The pool starts one worker for each 40 million bytes of work, at most `concurrency` of them. The instrumenter parses in its process when that gives fewer than two workers, which includes a `concurrency` of 1, so a file with little to parse starts no process. The workers that the pool has stay for the next file, and a file that needs more starts the others.

A worker pays for its start when it saves more parse time than the start costs. With the Windows figures, two workers break even at 18 million bytes of work for each, and every worker beyond two breaks even at less. At 40 million bytes of work for each worker, the time that the workers save is at least 2.2 times the time that they take to start on Windows, which starts slowest of the three systems.

Both ways give the same verdicts, because both make the text with the same patches and parse it with the same call. The site tests check it on every kind of site: each of them instruments its source once with the parses in the test's process and once with a pool, and the two results must be equal.

### When a worker fails

A worker that ends, writes a line that is not a verdict, or doesn't finish a line within its time limit makes the pool raise `Stryker::Instrumenter::Error`. The message gives the ID and file of the mutant whose plain mutant the worker was parsing, and the last 10 lines that the worker wrote to its standard error, when it wrote any. No verdict that a worker didn't give reaches the instrumenter: an error is never a mutant that survives.

No worker outlives its pool. The pool ends every worker when it stops, when the block that opened it ends, and when it raises, and the next use of a pool that raised starts new workers. The pool starts each worker with its standard error going to a temporary file, and deletes the file when it stops the worker. A pipe that nothing reads fills up, and a worker that writes to a full pipe waits for ever, so a file stands in for the pipe. What a worker writes to its standard error reaches the message of the error that its failure raises, and appears nowhere else.

The time limit of a read from a worker is 100 times the time that parsing the file takes in the orchestrator, and at least 30 seconds. The pool measures that time once for each file, by parsing the file in the orchestrator before it reads from any worker. The pool kills a worker that hasn't finished a line when the limit ends, even when it has written the start of one, and the message says how long the limit was.

The factor and the floor come from reads in a pool with as many workers as the computer has processors, on an idle computer and beside CPU-bound processes, up to three for each processor. The table gives, for each file, the time of one parse in the orchestrator and the longest read after a worker's first, as a multiple of that time.

| File | One parse in the orchestrator | Longest read, as a multiple |
| - | - | - |
| 1.6 KB | 0.1 ms | 217 |
| 30 KB | 0.7 to 1.2 ms | 100 |
| 150 KB | 5 to 46 ms | 13 |
| 660 KB | 19 to 175 ms | 9 |
| 5.3 MB | 0.17 to 0.68 s | 2 |

A file of 30 KB or less parses in less time than the system takes to switch to a worker and back, which took 13 to 80 ms, so the multiple for such a file is large and its read is short. The longest read of any file took 1.1 seconds. The factor of 100 is 7 times the largest multiple for a file of 150 KB or more, and the floor of 30 seconds is 27 times the longest read. A worker's first read also waits for the worker to start. That took up to 1.2 seconds, and a pool of 32 workers took 5 to 9 seconds to start on Windows, so the floor is more than three times the longest start. The limit leans long: a limit that a healthy worker reaches stops a healthy run, and one that a stuck worker reaches costs the run 30 seconds or more, once, when it stops with the error.

## Loading instrumented code

### The `load_iseq` hook

Ruby compiles every file it loads from disk, whether through `require`, `require_relative`, `load`, or an autoload such as Zeitwerk's. Before it compiles one, CRuby calls `RubyVM::InstructionSequence.load_iseq(path)`, if that method exists. When the method returns an instruction sequence, Ruby runs it in place of compiling the file. When it returns `nil`, Ruby compiles the file as usual.

The loader prepends a module to `RubyVM::InstructionSequence.singleton_class` that defines `load_iseq`. For each call, the module does one of two things:

- When `path` is an instrumented file's path ([Finding an instrumented file](#finding-an-instrumented-file)), it reads that file's instrumented source from the cache, compiles it with `RubyVM::InstructionSequence.compile`, giving the original `path` as the file name and the file's real path as the path, records that it served that file, and returns the result.
- For any other file, it calls `super` when a module further down the chain defines `load_iseq`, and returns `nil` otherwise. Ruby has no default `load_iseq`, so a bare `super` raises `NoMethodError` when nothing else has prepended one.

In both cases, when a test is running, the module records `path` as a file whose load began during that test. [Coverage](coverage.md#static-hits-inside-a-test) says what the recorder does with it.

Because Ruby still resolves the file and still compiles the code under its original path, `__FILE__`, `require_relative`, `$LOADED_FEATURES`, and the file names in backtraces all show the path that Ruby gave. `__dir__` and each frame's `absolute_path` show the file's real path, as they do for a file that Ruby compiles itself. The two differ when Ruby gives the hook a path that isn't the file's real path, as it does for a `require` of an absolute path through a symbolic link. Zeitwerk works unchanged: every instrumented file of a project that Zeitwerk autoloads or eager-loads comes through the hook.

The hook resolves the real path once for each file it serves.

A served file differs from the same file under plain Ruby in one way. Its top-level frame is labeled `<compiled>`, where Ruby labels the top-level frame of a file it compiles itself `<top (required)>`. `RubyVM::InstructionSequence.compile` sets the label, and no option changes it. A test that matches `<top (required)>` in a backtrace or in a `caller_locations` label sees `<compiled>` for an instrumented file. The stack check allows for the label ([The stack check](coverage.md#the-stack-check)).

The loader installs the hook before any of the project's code loads, in every project process.

`load_iseq` is part of CRuby's `RubyVM` API. JRuby and TruffleRuby don't call it, so **Stryker (for Ruby)** runs on CRuby only.

The hook serves Ruby files.

### Finding an instrumented file

The hook finds an instrumented file in up to two steps:

1. It looks up the key of `path` in the table ([The cache](#the-cache), [Paths on Windows](#paths-on-windows)). The lookup is one Hash lookup, with no system call.
2. When the table has no such key, but the base name of `path`, with letter case folded, is the base name of one of the keys, the hook resolves `path`'s real path and looks up its key. A `load` of a file in the working directory gives `path` as it was written, relative, so the hook resolves it against the working directory first, as Ruby does when it opens the file. A `load` through a second symbolic link, or in other letter case on a file system that folds it, such as the default macOS file system, gives a path that the table doesn't have, and a `load` adds nothing to `$LOADED_FEATURES`, so the loading check can't see the miss. The hook records a file found this way under the path that Ruby gave, as it does for any other.

Letter case is folded on every system, because a file system can fold it whatever the platform's convention. A path whose base name no instrumented file has is never resolved, so the hook pays for the real path only where a file may be instrumented. A file in another folder with the same base name as an instrumented file is resolved, and found not to be instrumented.

One lookup costs this much on macOS, as the median of 7 rounds of 100,000 lookups in a table of 500 instrumented files (the rows that resolve a real path, of 5,000 lookups each):

| Path | Cost of the lookup |
| - | - |
| A path with a key in the table | 0.2 µs |
| No key, and a base name that no instrumented file has | 0.4 µs |
| No key, a base name that an instrumented file has, and no file at the path | 3.5 µs |
| No key, a base name that an instrumented file has, and a symbolic link to the instrumented file | 30 to 40 µs |

The last row is the cost of resolving the real path of a file that exists, and each load of such a file pays it.

### Keeping the hook ahead of Bootsnap

Bootsnap, for its compile cache, prepends a module with a `load_iseq` method to the same singleton class. Of two prepended modules, Ruby calls the one prepended last first, and Bootsnap's `load_iseq` doesn't call `super`. So a Bootsnap module prepended after the hook would serve the original file, and every mutant in it would have no effect, with no error raised.

A new Rails 8.1 app sets up Bootsnap from its test helper, after the hook: `test/test_helper.rb` requires `config/environment`, which requires `config/application`, which requires `config/boot`, and `config/boot.rb` runs `require "bootsnap/setup"`. Turning Bootsnap's compile cache off doesn't help. Requiring `bootsnap` calls `Bootsnap::CompileCache::ISeq.install!(nil)`, which prepends the module even when `DISABLE_BOOTSNAP` or `DISABLE_BOOTSNAP_COMPILE_CACHE` is set, or when the app calls `Bootsnap.setup(compile_cache_iseq: false)`. With no cache directory, the module's `load_iseq` leaves the original file to Ruby, or compiles it itself when the app uses Bootsnap's frozen string literal compiler, and still doesn't call `super`.

So the loader keeps the hook in front. When it installs the hook, before any of the project's code loads, it also overrides `prepend` on `RubyVM::InstructionSequence.singleton_class`. Whenever a module that defines `load_iseq` is prepended after the hook, the override prepends a new copy of the hook module in front of it. The copy is new because Ruby doesn't move a module that is already among the ancestors, so prepending the first hook module again would change nothing.

Bootsnap prepends its module twice, so two copies of the hook stack in front of it. Both behave the same: for an instrumented file, the front copy serves the instrumented source; for any other file, each copy calls `super`, and Bootsnap serves the file from its cache as usual. The override covers any library that prepends `load_iseq` after the hook, not only Bootsnap, whether the module it prepends defines `load_iseq` or includes a module that does, and whether the method is public or private. A library that bypasses `prepend`, such as by calling `Module#prepend_features` itself, gets past the override, and the loading check catches each file that this leaves uninstrumented.

### The loading check

The loading check catches an instrumented file that loaded without going through the hook, whatever the cause. The dry run, the first run of the whole suite with no mutant active, ends with it. For every instrumented file that appears in `$LOADED_FEATURES`, the loader confirms that the hook served it. A path in `$LOADED_FEATURES` matches an instrumented file when the path, or its real path, has one of that file's keys, so a file that the hook missed because Ruby gave it through another symbolic link is found too. The loader resolves a real path only for an absolute path. Ruby lists a built-in feature such as `thread.rb` by its bare name, and resolving that against the current directory would match a project's own `thread.rb`, which no hook served, and fail the dry run. A file counts as served only when the hook served it under the exact path that Ruby loaded it under. Ruby records a loaded file in `$LOADED_FEATURES` under the path it gave the hook, and one file can come under two paths, so a file that loaded under two spellings, with the hook serving one, is listed under the other. A second call to `install` in the same process replaces the table and starts the record of served files again, so a file served before it doesn't count. When any loaded instrumented file didn't come through the hook, the dry run fails, no mutant runs, and the error lists each such file. When a module that defines `load_iseq` sits ahead of the hook in the singleton class's ancestors, the error message gives that module's name, which is Bootsnap's `Bootsnap::CompileCache::ISeq::InstructionSequenceMixin` when Bootsnap is the cause.

The loading check covers Ruby files.

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

Every mutant run happens in a process that has run no test before it, and that process ends when the run does. Nothing is reused for a second run. `Isolation::FreshProcesses` gives each static mutant's run a fresh process with the mutant ID in its environment, on every system ([Static mutants on every system](#static-mutants-on-every-system)).

### The entry point

The orchestrator starts every project process with an array of arguments, never a string that a shell would parse: the running Ruby, `-r` with the path of `stryker/isolation/project_process.rb`, `-e Stryker::Isolation::ProjectProcess.main`, `--`, and then the arguments for the process itself: its mode, the cache's directory, the name of the test runner from the `testRunner` option, and what the mode needs:

| Mode | What it needs | Standard input | Standard output and standard error |
| - | - | - | - |
| `static` | The path of the file that holds its run, and the path of the file for its results | The null device | Files in the run's temporary folder |

Ruby's options end at `--`, so the rest reach `ARGV`. `main` takes every argument out of `ARGV` before any of the project's code loads, because `minitest/autorun` parses `ARGV` as Minitest's options. Requiring the entry point starts the runtime first, so the mutant whose ID `STRYKER_ACTIVE_MUTANT` holds is active before anything else loads. `main` then calls `Stryker::Runtime::Loader.install` with the cache's directory, builds the test runner adapter for the project in the current folder, and runs the mode. The orchestrator starts each process in the project's root, with `STRYKER_ACTIVE_MUTANT` set to the run's mutant, whatever the orchestrator's environment holds.

A project process ends with `exit!`, whatever its mode, once its work is done or has raised. `exit` would run every `at_exit` block, the project's included: `minitest/autorun`'s, and SimpleCov's, which writes its results into the project.

No result travels on standard output, on any system. Each project process's standard output and standard error go to files of its own, which `Isolation::OutputFiles` names, in the run's folder. A `RuntimeError`'s reason ends with the last 20 lines of the run's standard error.

### The protocol

Every message is one JSON object on a line of its own. Each process that reads one parses it with `JSON.parse` and never with `Marshal.load`, because the process that wrote it ran the project's tests. Each line goes in one write, in sync mode, so a write survives the writer's `exit!`, and the lines of two threads never mix.

A process that runs a mutant run writes, as it happens:

| Message | When |
| - | - |
| `{"started": <the test>}` | Just before each test starts |
| `{"finished": <the test's result>}` | As soon as each test finishes, through the test runner adapter's `test_finished` |
| `{"ended": true}` | When the run's last test has finished |
| `{"error": "<class>: <message>"}` | When the run raised instead, such as `SystemExit` from a test that calls `exit` |

A test's result crosses as soon as the test finishes ([#20](https://github.com/setdef/stryker_for_ruby/issues/20)), so a failure reaches the orchestrator even when the process dies right after it.

A fresh process reads its run from a file, as JSON, and writes its messages to another file, because Ruby on Windows hands a new process no descriptor beyond its standard input, output, and error: `Process.spawn` there refuses a descriptor of 3 or more. Both files are in a temporary folder for the run, which the orchestrator makes with `Dir.mktmpdir` and deletes once it has judged the run. Each line reaches the file when its test finishes, so a failure written before a crash is still there.

A stream that stops partway is read up to the last whole line. A last line with no line break is one the writer didn't finish, and is left out. The orchestrator trusts a run's messages up to the first line that is no message, such as a line that isn't JSON, an object with a key it doesn't know, and reads nothing after it.

### How a run's outcome becomes a status

The orchestrator judges each run from its messages and from how its process ended: its exit status or the signal that ended it, and whether it ran past its time limit. The first row that holds gives the status:

| What happened | Status | Reason |
| - | - | - |
| A test's result is `failed` | `Killed`, by that test | The test's failure message |
| The process ran past its time limit | `Timeout` | `Timeout of <N> ms exceeded.` |
| The run ended, every one of its tests finished without failing, and the process exited with status 0 | `Survived` | none |
| Anything else | `RuntimeError` | The error the process wrote, or how it ended, such as `The run's process exited with status 3 after 1 of its 2 tests finished, while Shop::CartTest#test_total ran.`, and then the last 20 lines of its standard error |

So a failed test kills the mutant whatever the process did after it said so: crashed, exited with an error, raised a signal at itself, or ran on until its time limit. A process that ends before its last test finished, crashes, or runs past its limit before any failure is never `Survived`. `tests_completed` counts the tests that finished. `covered_by` is the run's `covered_by`, for both kinds of mutant: the tests whose bucket held the mutant in the dry run. For a runtime mutant, those are the tests its run ran. A static mutant's run holds every test, and its `covered_by` lists only the tests that recorded a hit.

### Time limits and kills

A fresh process writes its messages to a file of its run's, and the orchestrator reads them once the process ended and enforces the run's time limit.

A run's time limit counts from the start of its process. Past it, the orchestrator sends KILL, and nothing gentler first: Ruby turns TERM into an exception that runs every `ensure` clause and `at_exit` block, the project's included, with the mutant still active. Where `setpgid` exists, as on Linux and macOS, every process that an adapter starts leads a process group of its own, so the KILL goes to the whole group, and the processes that the run's tests started die with it. The same KILL goes to the group of a process that ended by itself, for what its tests left running. The process itself is killed only while it hasn't been reaped. Windows has no process groups, so there the KILL ends the process alone, and nothing is killed once a process has ended, because Windows can give its ID to another process. A process that KILL ends on Windows exits with status 0, so only the record of its time limit marks the run `Timeout`, and the missing `ended` message keeps it from counting as `Survived`. The lines that a killed process wrote before the KILL count: a failure among them is still `Killed`.

`Isolation::FreshProcesses` learns that a fresh process ended from its waiter: it takes each process that has ended, and when none has, waits on the waiter of the process whose time ends first, until that process ends or its time does. A thread of `Process.detach` reaps each process, so none lingers as a zombie.

When the orchestrator stops an adapter, or a block given to `run_all` raises, the adapter ends every process it started before `stop` or `run_all` returns.

### Static mutants on every system

A static mutant's switch runs once, while its file loads. Setting the mutant active afterwards changes nothing, because the switch never runs again. A probe set a static mutant in a constant's value active after load, and the constant kept its original value.

So every static mutant run gets a fresh process, on every system, from `Isolation::FreshProcesses`, with the mutant ID in the `STRYKER_ACTIVE_MUTANT` environment variable before the process starts. The runtime reads that variable when it loads, before any of the project's code, and makes the active mutant's holder from it ([The active mutant's holder](#the-active-mutants-holder)), so the switch takes the mutated branch while the file loads. The process reads its run from a file, checks that the run's mutant is the active one, loads the project's tests, runs the run's tests, stopping at the first failure, and writes each test's start and result to its results' file as it happens. The run includes every test, because a value set at load time can reach any test.

The adapter keeps up to `concurrency` processes running at once, and enforces each run's time limit itself. It judges a run from its results' file once its process ended, and then deletes the run's folder. A runtime mutant's run works in a fresh process too, at the cost of a process for each run.

## Ractors

The switch and the hook can run in a Ractor other than the main one. This section specifies how the active mutant's ID is read there, how the hook behaves there, and why every lookup table is shareable. [Coverage](coverage.md#ractors) specifies how a hit made there is recorded. The probes ([#13](https://github.com/setdef/stryker_for_ruby/issues/13)) ran Ruby 3.3, 3.4, 4.0, and 4.1-dev on macOS, and 3.3, 3.4, and 4.0 on Linux.

### The active mutant's holder

`::Stryker::Active` is a constant that holds a frozen object made shareable with `Ractor.make_shareable`. A non-main Ractor can read a constant that holds a shareable object, a frozen `Data` value, or an Integer. A constant that holds an unshareable object raises `Ractor::IsolationError` there, and so does a global variable. So neither holds the active ID.

A forked child, or a fresh process that reads `STRYKER_ACTIVE_MUTANT`, replaces the constant before its run starts: it calls `remove_const`, and then `const_set` with a new shareable holder for the mutant's ID. In the probes, the replacement took effect in the main Ractor and in every other Ractor, including in code compiled before the fork, with no warning. The switch's text stays as [Mutant placement](mutant-placement.md#the-switch) specifies it. A check through a shareable holder's `attr_reader` costs about 8 to 11 ns, in the main Ractor and in others alike.

### The hook in a non-main Ractor

The hook reads the cache through a shareable table, so it works in a non-main Ractor. It records each file whose load began there through the collector Ractor ([Coverage](coverage.md#ractors)), as a switch records a hit.

`load` in a non-main Ractor calls the hook in that Ractor. `require` there runs in the main Ractor, so the hook serves the instrumented source there. On Ruby 4.1, a non-main Ractor can't prepend to `RubyVM::InstructionSequence`.

The hook records the files it served only in the main Ractor, because the loading check reads only `$LOADED_FEATURES`, and a `load` adds nothing to it. A `require` in a non-main Ractor runs in the main Ractor, where the hook records the file. On Ruby 4.1, a file that sets a constant can't load in a non-main Ractor at all, with or without **Stryker (for Ruby)**.

Ruby 3.3 and 3.4 are unsupported. [Ruby 3.3 and 3.4](../older-ruby.md) lists what goes wrong in a non-main Ractor there.

### Lookup tables

Every lookup table that the runtime keeps is shareable, because a non-main Ractor that reads a constant holding an unshareable object raises `Ractor::IsolationError`.

## What this design doesn't do

- It doesn't reuse a process for a second run, on any system.
- It doesn't run on Ruby implementations other than CRuby.
- It doesn't turn Bootsnap off or change its settings. Files that aren't instrumented still load through Bootsnap's cache.
- It doesn't load Prism or refract in a project process.
- It doesn't restart a parse worker that failed: a worker's failure raises an error and ends the pool.
- It doesn't attribute a hit made on another thread or a fiber to a file that loads inside a test.
- It doesn't find an instrumented file that a `load` reaches through a symbolic link with a base name that no instrumented file has. A `load` adds nothing to `$LOADED_FEATURES`, so nothing reports it.
- It doesn't write instrumented source into the project.
- It doesn't end a process that a test started and that left the run's process group. On Windows, which has no process groups, it doesn't end a process that a fresh process started and that outlives the run.
- It doesn't run the project's `at_exit` blocks in a project process, or the `ensure` clauses of a run that it kills for its time.
- It doesn't read a static mutant's results before the run's process ends.
