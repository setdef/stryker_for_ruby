# Coverage

This page specifies how **Stryker (for Ruby)** learns which tests reach each mutant, and which mutants are static. The plan uses that map to run each mutant against only the tests that reach it, and to give a mutant that no test reaches the status `NoCoverage` without running it. The terms used here are defined in [Loading and isolation](loading-and-isolation.md#terms).

## Hits

Every switch in the instrumented code records a hit when it runs in the dry run: the IDs of the mutants it holds go into the current bucket of a hit recorder in the Stryker runtime. A mutant run records no hits: `hit` returns at once, because a mutant run doesn't use the map. A hit means that the code at the mutant's site ran, so a test that recorded one would see the mutant's effect if the mutant were active.

The recorder has two kinds of bucket:

- **The static bucket** is current from the moment the runtime loads until the first test starts, and again between tests. Hits recorded while the project's code and tests load land here. A hit made while a file loads inside a test lands here too, as [Static hits inside a test](#static-hits-inside-a-test) specifies.
- **A test's bucket** is current while that test runs. The test runner adapter tells the recorder when each test starts and when it finishes, so each test's hits land in that test's bucket, apart from every other test's.

A hit costs about 17 to 66 ns, depending on the Ruby version, on whether YJIT is on, and on the machine. The probes timed Ruby 3.3, 3.4, and 4.0 on Linux and macOS.

A switch can also run in a Ractor other than the main one. [Ractors](#ractors) says how a hit from there is recorded.

## The dry run

The dry run runs every test once, with no mutant active, in a separate process. It reports, for each test, its result, its time, and the mutant IDs in its bucket. It also reports the static bucket, and every file first loaded during a test. When any test fails, the dry run fails and no mutant runs, because a mutant can't be judged by a test that fails without it.

## How the plan uses the map

| What the dry run recorded for a mutant | Its status or run |
| - | - |
| No hit at all | `NoCoverage`, and it doesn't run. |
| A static hit, with or without hits in tests' buckets | A static run: a fresh process with the mutant active before load, running every test. |
| Hits in one or more tests' buckets only | A runtime run of exactly those tests, which the report lists as the mutant's `coveredBy`. |

A static run includes every test because a value set while a file loads can reach any test, whichever tests recorded hits. The same rule covers hits recorded between tests, such as in an RSpec `before(:context)` hook, which runs outside any single test.

When every file loads before the first test, the static bucket identifies static mutants exactly. A probe ran each of 29 Minitest tests once against each of 64 mutants, each pair in a separate process, and stopped the process the first time that mutant's switch ran, noting whether a test had started. That gave the true set of 8 static mutants, and the hits recorded before the first test were the same 8.

A file that the project first requires inside a test loads while that test runs, so its load-time hits would land in the test's bucket. The next section says how the recorder tells them from runtime hits.

## Static hits inside a test

A file that the project first loads inside a test, rather than from the test helper or from a file loaded before the tests, runs its load-time code while that test runs. Without a further rule, its switches record their hits in that test's bucket, and a mutant in a constant's value or a class body is planned as a runtime mutant. A static mutant run as a runtime mutant has no effect, because its switch never runs again once the file has loaded. The mutant then survives whatever the tests do.

Loading every file before the first test would avoid this, but it changes when the project's files load, and **Stryker (for Ruby)** changes nothing in your project. So the recorder tells static hits from runtime hits by the call stack.

### The rule

A hit is static when either of these holds:

1. It lands outside any test: before the first test, or between tests. This covers an RSpec `before(:context)` hook and code that a test file runs at its top level.
2. It lands inside a test, and the stack holds the top-level frame of a file whose load began during that test.

A static hit goes into the static bucket.

### Files whose load began

The hook (see [The `load_iseq` hook](loading-and-isolation.md#the-load_iseq-hook)) sees every file that Ruby compiles from disk, instrumented or not. It records the path of each file whose load begins while a test runs, so the recorder holds, for the current test, the paths of the files that began to load in it. A file outside `mutate` that loads inside a test is recorded like an instrumented one, so a hit that its top-level code causes in the project's code counts as static.

### The stack check

A top-level frame is the outermost frame of a file's load, and its label says how Ruby compiled the file:

| Label | Which files |
| - | - |
| `<compiled>` | A file the hook compiled with `RubyVM::InstructionSequence.compile`, which includes every instrumented file. |
| `<top (required)>` | A file Ruby compiled itself. |
| `<main>` | A file Bootsnap compiled. |

The check walks the stack and looks for a frame whose `absolute_path` is the path of a recorded file, or that path with every symbolic link and `..` resolved, and whose label is one of the three. A file the hook compiles shows the path the hook gave; a file Ruby or Bootsnap compiles shows its real path. On Windows, the check normalizes both sides as the loader does ([Paths on Windows](loading-and-isolation.md#paths-on-windows)), with each `\` turned into `/` and letter case folded, so the stack check and the loading check agree. On other systems it compares paths as they are. The check reads `absolute_path` before the label, because testing the label first costs about three times as much on Ruby 3.4 and 4.0. It reads the label as well as the path because a frame inside a method that the file defines has the file's path, and so does a C-implemented frame such as `Array#each` that a method of the file called. On Ruby 3.4 and later, the label of such a C frame includes the class name. The check reads the whole stack: a limited `caller_locations(1, n)` misses a top-level frame deeper than `n`, so it gives wrong answers.

A class or module body, and a block that runs while the file loads, have the top-level frame beneath them, so their hits are static. A block that runs after the load finishes, such as a `define_method` body, an `at_exit` block, or a thread's block, has no top-level frame, so its hits stay in the test's bucket.

### When the check runs

The check runs only after a file has begun to load during the current test. A test that loads no file makes no stack check, so the cost falls only on projects that load files lazily.

After each such load, the next hit of each mutant is checked again, even when the mutant is already in the test's bucket. Without that, a mutant that the test itself reached first, and that a file reached later in the same test while it loaded, would stay out of the static bucket. Checking whether a mutant is already in the current bucket adds no measurable cost per hit.

One check costs this much, with `absolute_path` tested first, on Linux and on Ruby 3.3 to 4.0 with YJIT off or on:

| Frames on the stack | One check |
| - | - |
| 20 | 1.7 to 2.4 µs |
| 100 | 5.5 to 7.6 µs |
| 300 | 16 to 21 µs |

A test body has 18 to 25 frames under Minitest, RSpec, and Rails.

### What the probes found

A probe ran the 29 Minitest tests and 64 mutants described above, with the 8 static mutants and 76 true (test, mutant) pairs as the ground truth, in two layouts. It ran on Ruby 3.3, 3.4, 4.0, and 4.1-dev, on macOS and Linux.

| Rule | Every file required before the tests | Each file first required inside a test |
| - | - | - |
| Only hits outside any test count as static | 8 static mutants, 76 true pairs, 0 false | 0 static mutants, 76 true pairs, 8 false |
| The rule above | 8 static mutants, 76 true pairs, 0 false | 8 static mutants, 76 true pairs, 0 false |

Fixtures that the two rules together handled correctly:

- a constant set while a file loads inside a test
- `X ||= ...`
- a method called at load and from tests
- `Struct.new` and `Data.define` bodies
- RSpec `before(:context)`
- a test file's top level calling the project's code
- a Rails model first autoloaded inside a test, with Bootsnap in front of the hook

### The known gap

A hit made on another thread or a fiber while a file loads inside a test isn't attributed to the load. A thread's stack and a fiber's stack, including the stack of an external enumerator run with `Enumerator#next`, have no top-level frame. The hit stays in the test's bucket, and the mutant is planned as a runtime mutant with only the tests that recorded it, so a test that also depends on the file's load-time values isn't in its run.

Counting every hit on another thread or fiber as static was rejected. In a test that loads a file and runs the app in a server thread, as Rails system tests do, every mutant that the server thread reaches would become static, and every one of them would run against the whole suite in a fresh process.

The dry run doesn't guess about this. It reports every file first loaded during a test, and lists each file, so the project can see which results rest on this rule.

## Ractors

A hit made in the main Ractor goes straight to the recorder. A hit made in another Ractor can't: the standard library has no mutable structure that Ractors can share, Ractor-local storage can't be read by another Ractor, and a frozen IO can't be written. How the hit reaches the recorder depends on the Ruby version. The probes ([#13](https://github.com/setdef/stryker_for_ruby/issues/13)) ran Ruby 3.3, 3.4, 4.0, and 4.1-dev on macOS, and 3.3, 3.4, and 4.0 on Linux. [Loading and isolation](loading-and-isolation.md#ractors) says how the switch reads the active mutant's ID in a Ractor, and how the hook, forking, and the lookup tables behave there.

### Ruby 4.0 and later

On Ruby 4.0 and later, the runtime starts a collector Ractor in every process that records hits, and a switch in another Ractor sends each hit to it. A process records hits when no mutant is active: the fork parent, which starts its collector as the runtime loads, before the project's code, and the dry run's forked child. A forked child can't use its parent's Ractors, so the dry run's child starts a collector of its own after the fork. A mutant run starts none, and its `hit` returns at once.

The fork parent runs no test, so it drains its collector before each fork, and a hit that a Ractor made while the project loaded is in the static bucket that every child inherits. In the dry run, the recorder drains the collector when each test starts and when it ends:

- A hit sent between tests is drained when the next test starts, before that test's bucket becomes current, so it lands in the static bucket.
- A hit from a Ractor that finished during a test is drained when the test ends, so it lands in that test's bucket.

A collector that was drained only when each test ends put a hit sent between tests in the next test's bucket, which is why the recorder drains at the start as well. In the probe, every hit arrived, including the hits from Ractors that finished during the test.

Sending a hit to the collector costs about 115 to 200 ns. A hit in the main Ractor costs about 30 ns, or 11 ns with YJIT.

#### Ruby's warning that Ractors are experimental

When `Warning[:experimental]` is on, Ruby 4.0 and later print "Ractor API is experimental and may change in future versions of Ruby." for the first Ractor that a process starts. `Ractor.new` checks whether the process is still in single-Ractor mode, and starting a Ractor ends that mode for good. A second `Ractor.new` prints nothing, even after the first Ractor has finished, and `Ractor::Port.new` starts no Ractor and prints nothing. A forked child is in single-Ractor mode again, so Ruby warns again for the child's first Ractor.

So the collector, which starts before the project's code does, takes the warning that the project's first Ractor would have had. The runtime can't keep it for the project, and it must not print Ruby's warning in the project's place. It starts the collector with `Warning[:experimental]` turned off, puts the setting back, and writes one line to standard error, before the project's code runs:

> Stryker (for Ruby) started a Ractor to record hits from your Ractors. Ruby warns that Ractors are experimental only for the first Ractor a process starts, so it won't print that warning for yours.

The runtime writes the line only when the warning was on. Every process that starts a collector writes it, so the dry run's forked child writes it again. On Ruby 3.3 and 3.4 the runtime starts no Ractor, so it writes nothing and the project's first Ractor gets Ruby's warning.

### Ruby 3.3 and 3.4

On Ruby 3.3 and 3.4, no mechanism that the probes tried records a hit from a non-main Ractor reliably. A send from a thread inside a non-main Ractor hangs. A thread in the main Ractor that reads a port or `Ractor.main` never ran while the test's main thread waited on a Ractor, so no hit arrived. So in a process that records hits, a switch that runs in a non-main Ractor raises `Stryker::UnsupportedError`, and its message mentions Ruby 4.0. The test fails, the dry run fails, and no mutant runs. The run fails loudly instead of losing hits.

### A Ractor still running when its test ends

A hit from a Ractor that is still running when its test ends can't be put in that test's bucket by any mechanism that the probes tried. It joins the known gap for threads and fibers that [Static hits inside a test](#the-known-gap) describes: the test isn't recorded as reaching the mutant, so the mutant's run can leave it out.

### Switches inside shareable procs

A switch never changed whether a block can be isolated or shared. Every form behaved the same with the switch as without it, once the active mutant's holder was shareable.

## Why not Ruby's `Coverage` library

Ruby's standard `Coverage` library can measure which lines each test runs: start it in lines mode, and after each test call `Coverage.result(stop: false, clear: true)`. Mapping those lines to the mutants on them gives a second way to build the map. It gives the wrong map.

The same probe as above compared the two ways against the true set of (test, mutant) pairs, leaving out the static mutants:

| Way | Pairs found that are true | Pairs found that are false | True pairs missed |
| - | - | - | - |
| Hits recorded by the switches | 76 of 76 | 0 | 0 |
| `Coverage` in lines mode, cleared after each test | 61 of 76 | 35 | 15 |

The errors have two causes:

- **Several mutants share a line.** A line that a test runs maps to every mutant on it, though the test may reach only some of them, such as the left side of an `a && b` that stops at `a`. In the probe, 47 of the 64 mutants shared a line with another mutant. Each false pair runs a mutant against a test that can't kill it, and lists that test in the report's `coveredBy`.
- **Lines go missing after a clear.** After `Coverage.result(clear: true)`, the body of an endless method, such as `def add(a, b) = a + b`, wasn't counted again when a later test ran it. Each missed pair leaves a test out of a mutant's run, and a mutant that only that test would kill is reported as surviving.

`Coverage` in `oneshot_lines` mode counts each line only the first time it runs in the process, and a clear doesn't reset that, so it can't map lines to any test but the first to run them.

Hits avoid both causes, because each switch records the IDs of the mutants it holds, and a switch runs exactly when the code at its sites does.

## What this design doesn't do

- It doesn't measure line or branch coverage of the project's code. Use SimpleCov or `Coverage` for that.
- It doesn't record hits in a mutant run.
- It doesn't record a hit from a non-main Ractor on Ruby 3.3 or 3.4. The dry run fails instead.
- It doesn't attribute a hit from a Ractor that is still running when its test ends to that test.
- It doesn't keep the map between runs. Each run of **Stryker (for Ruby)** starts with a new dry run.
