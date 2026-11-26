# Coverage

This page specifies how **Stryker (for Ruby)** learns which tests reach each mutant, and which mutants are static. The plan uses that map to run each mutant against only the tests that reach it, and to give a mutant that no test reaches the status `NoCoverage` without running it. The terms used here are defined in [Loading and isolation](loading-and-isolation.md#terms).

## Hits

Every switch in the instrumented code records a hit when it runs in the dry run: the IDs of the mutants it holds go into the current bucket of a hit recorder in the Stryker runtime. A mutant run records no hits: `hit` returns at once, because a mutant run doesn't use the map. A hit means that the code at the mutant's site ran, so a test that recorded one would see the mutant's effect if the mutant were active.

The recorder has two kinds of bucket:

- **The static bucket** is current from the moment the runtime loads until the first test starts, and again between tests. Hits recorded while the project's code and tests load land here. A hit made while a file loads inside a test lands here too, as [Static hits inside a test](#static-hits-inside-a-test) specifies.
- **A test's bucket** is current while that test runs. The test runner adapter tells the recorder when each test starts and when it finishes, so each test's hits land in that test's bucket, apart from every other test's. A test that starts again, as a retry through `minitest-retry` or `rspec-retry` starts it, adds to the bucket it already has, because every attempt reached those mutants. On Minitest 6, `minitest-retry` runs every attempt between one start and one finish, so its attempts share one bucket that way too ([Test runners](test-runners.md#retries)).

The recorder takes a lock around every change to its buckets and every read of them, so a test's threads can record hits while the test runner adapter starts and ends tests.

[What a hit costs](#what-a-hit-costs) gives the cost of a hit and of reading the active mutant's ID.

A switch can also run in a Ractor other than the main one. [Ractors](#ractors) says how a hit from there is recorded.

## What a hit costs

Each figure is the cost of one call in nanoseconds, from `Stryker::Active.hit` and `Stryker::Active.id` as the runtime ships them. It is the median of 9 rounds of 3,000,000 calls, less the cost of an empty loop, on Linux, on a machine that other work shared. A figure under 10 ns is within the noise of the measurement.

| One call | 3.3.14 | 3.3.14 YJIT | 3.4.13 | 3.4.13 YJIT | 4.0.10 | 4.0.10 YJIT |
| - | - | - | - | - | - | - |
| `id`, in the main Ractor | 14 | 14 | 14 | 12 | 12 | 11 |
| `id`, in another Ractor | 12 | 12 | 12 | 12 | 10 | 12 |
| `hit`, no test running (the static bucket) | 190 | 80 | 191 | 91 | 185 | 82 |
| `hit` with two mutants at the site, no test running | 227 | 101 | 231 | 114 | 220 | 104 |
| `hit`, a test running | 231 | 88 | 252 | 86 | 232 | 87 |
| `hit`, a test running, after a file began to load, for a mutant already checked | 349 | 141 | 348 | 145 | 348 | 138 |
| `hit`, a mutant active | 42 | 40 | 41 | under 10 | 41 | under 10 |
| `hit`, in another Ractor | not recorded | not recorded | not recorded | not recorded | 748 | 543 |

Each `hit` row in the main Ractor is a hit of a mutant already in the current bucket, the usual case: the recorder returns after a membership check, without a merge and without taking its lock. The first hit of a mutant in a bucket takes the lock and merges. A mutant run pays only the `id` read and the `hit` that returns at once, because it records nothing. The first `hit` of a mutant after a file begins to load also pays for one stack check, which [When the check runs](#when-the-check-runs) prices.

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

A file that the project first loads inside a test, rather than from the test helper or from a file loaded before the tests, runs its load-time code while that test runs. Without a further rule, its switches record their hits in that test's bucket, and a mutant in a constant's value or a class body is planned as a runtime mutant. A static mutant run as a runtime mutant has no effect, because its switch never runs again once the file has loaded. The mutant then survives whatever the tests do. A probe that required such a file in one test and used its constant in a second test recorded the constant's mutant as reached by the first test only.

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

The check walks the stack and looks for a frame whose `absolute_path` is the path of a recorded file, or that path with every symbolic link and `..` resolved, and whose label is one of the three. Every file shows its real path, whether the hook, Ruby, or Bootsnap compiled it. On Windows, the check normalizes both sides as the loader does ([Paths on Windows](loading-and-isolation.md#paths-on-windows)), with each `\` turned into `/` and letter case folded, so the stack check and the loading check agree. On other systems it compares paths as they are. The check reads `absolute_path` before the label, because testing the label first costs about three times as much on Ruby 3.4 and 4.0. It reads the label as well as the path because a frame inside a method that the file defines has the file's path, and so does a C-implemented frame such as `Array#each` that a method of the file called. On Ruby 3.4 and later, the label of such a C frame includes the class name. The check reads the whole stack: a limited `caller_locations(1, n)` misses a top-level frame deeper than `n`, so it gives wrong answers.

A class or module body, and a block that runs while the file loads, have the top-level frame beneath them, so their hits are static. A block that runs after the load finishes, such as a `define_method` body, an `at_exit` block, or a thread's block, has no top-level frame, so its hits stay in the test's bucket.

### When the check runs

The check runs only after a file has begun to load during the current test. A test that loads no file makes no stack check, so the cost falls only on projects that load files lazily.

After each such load, the next hit of each mutant on each thread is checked again, even when the mutant is already in the test's bucket. Without that, a mutant that the test itself reached first, and that a file reached later in the same test while it loaded, would stay out of the static bucket. The recorder keeps a separate record for each thread of the mutants checked on it since the last load, because only the thread that loads the file has its top-level frame: a hit on a server thread, checked and found to be the test's, doesn't spare the loading file's own hit of that mutant its check.

A mutant that a file's load reaches twice is checked once, so the second hit lands in the test's bucket as well as the first in the static bucket. The plan gives a mutant with a static hit a static run whatever its tests' buckets hold, so the result is the same.

One check costs this much, with `absolute_path` tested first, on Linux and on Ruby 3.3.14, 3.4.13, and 4.0.10 with YJIT off or on, measured as in [What a hit costs](#what-a-hit-costs):

| Frames on the stack | One check |
| - | - |
| 23 | 1.5 to 2.3 µs |
| 103 | 6.0 to 9.8 µs |
| 303 | 17.5 to 28.8 µs |

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

A hit made in the main Ractor goes straight to the recorder. A hit made in another Ractor can't: the standard library has no mutable structure that Ractors can share, Ractor-local storage can't be read by another Ractor, and a frozen IO can't be written. The probes ([#13](https://github.com/setdef/stryker_for_ruby/issues/13)) ran Ruby 3.3, 3.4, 4.0, and 4.1-dev on macOS, and 3.3, 3.4, and 4.0 on Linux. [Loading and isolation](loading-and-isolation.md#ractors) says how the switch reads the active mutant's ID in a Ractor, and how the hook and the lookup tables behave there. Ruby 3.3 and 3.4 have no `Ractor::Port`, which this design needs, so they are unsupported: [Ruby 3.3 and 3.4](../older-ruby.md#a-hit-from-a-non-main-ractor-cant-be-recorded) says what happens there.

### The collector Ractor

Every process that records hits has a collector, and a switch in another Ractor sends each hit to the collector's Ractor. A process records hits when no mutant is active. The collector's Ractor starts when the project makes its first Ractor: the runtime prepends a module to `Ractor`'s singleton class whose `new` starts the collector's Ractor and then calls `super`. A project that makes no Ractor gets none from the runtime. A forked child can't use its parent's Ractors, so the dry run's child readies a collector of its own after the fork, and its Ractor starts at the child's first `Ractor.new`. A mutant run has no collector, and its `hit` returns at once.

In the dry run, the recorder drains the collector when each test starts and when it ends:

- A hit sent between tests is drained when the next test starts, before that test's bucket becomes current, so it lands in the static bucket.
- A hit from a Ractor that finished during a test is drained when the test ends, so it lands in that test's bucket.

A collector that was drained only when each test ends put a hit sent between tests in the next test's bucket, which is why the recorder drains at the start as well. In the probe, every hit arrived, including the hits from Ractors that finished during the test.

A file whose load begins in another Ractor reaches the recorder the same way.

On Ruby 4.0.10, a hit in another Ractor costs 543 to 748 ns, because it sends the hit to the collector, against 82 to 185 ns for a hit in the main Ractor outside a test. [What a hit costs](#what-a-hit-costs) has the figures.

#### Ruby's warning that Ractors are experimental

When `Warning[:experimental]` is on, Ruby 4.0 and later print "Ractor API is experimental and may change in future versions of Ruby." for the first Ractor that a process starts, with the file and line of the code that called `Ractor.new`. `Ractor.new` checks whether the process is still in single-Ractor mode, and starting a Ractor ends that mode for good. A second `Ractor.new` prints nothing, even after the first Ractor has finished, and `Ractor::Port.new` starts no Ractor and prints nothing. A forked child is in single-Ractor mode again, so Ruby warns again for the child's first Ractor.

The collector's Ractor is the process's first, so Ruby warns for it, with the warning as the project set it. Ruby's `Kernel#warn(uplevel: 0)` prints the file and line of the first caller whose path doesn't start with `<internal:`, so the runtime compiles its `new` under such a path, and the warning shows the project's line. The project sees exactly the warning it would see without **Stryker (for Ruby)**, in the parent and in a forked child. A `Ractor.new` without a block raises before Ruby warns, so it starts no collector either.

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
- It doesn't attribute a hit from a Ractor that is still running when its test ends to that test.
- It doesn't record a hit from a Ractor that started before the runtime loaded. Such a hit raises `Stryker::UnsupportedError`.
- It doesn't keep the map between runs. Each run of **Stryker (for Ruby)** starts with a new dry run.
