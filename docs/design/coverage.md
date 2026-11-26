# Coverage

This page specifies how **Stryker (for Ruby)** learns which tests reach each mutant, and which mutants are static. The plan uses that map to run each mutant against only the tests that reach it, and to give a mutant that no test reaches the status `NoCoverage` without running it. The terms used here are defined in [Loading and isolation](loading-and-isolation.md#terms).

## Hits

Every switch in the instrumented code records a hit when it runs: the IDs of the mutants it holds go into the current bucket of a hit recorder in the Stryker runtime. A hit means that the code at the mutant's site ran, so a test that recorded one would see the mutant's effect if the mutant were active.

The recorder has two kinds of bucket:

- **The static bucket** is current from the moment the runtime loads until the first test starts, and again between tests. Hits recorded while the project's code and tests load land here.
- **A test's bucket** is current while that test runs. The test runner adapter tells the recorder when each test starts and when it finishes, so each test's hits land in that test's bucket, apart from every other test's.

A hit costs about 17 to 66 ns, depending on the Ruby version, on whether YJIT is on, and on the machine. The probes timed Ruby 3.3, 3.4, and 4.0 on Linux and macOS.

## The dry run

The dry run runs every test once, with no mutant active, in a separate process. It reports, for each test, its result, its time, and the mutant IDs in its bucket, and it reports the static bucket. When any test fails, the dry run fails and no mutant runs, because a mutant can't be judged by a test that fails without it.

## How the plan uses the map

| What the dry run recorded for a mutant | Its status or run |
| - | - |
| No hit at all | `NoCoverage`, and it doesn't run. |
| A hit in the static bucket, with or without hits in tests' buckets | A static run: a fresh process with the mutant active before load, running every test. |
| Hits in one or more tests' buckets only | A runtime run of exactly those tests, which the report lists as the mutant's `coveredBy`. |

A static run includes every test because a value set while a file loads can reach any test, whichever tests recorded hits. The same rule covers hits recorded between tests, such as in an RSpec `before(:context)` hook, which runs outside any single test.

The static bucket identifies static mutants exactly. A probe ran each of 29 Minitest tests once against each of 64 mutants, each pair in a separate process, and stopped the process the first time that mutant's switch ran, noting whether a test had started. That gave the true set of 8 static mutants, and the hits recorded before the first test were the same 8.

One case puts load-time hits in a test's bucket: a file that the project first requires inside a test. [Loading and isolation](loading-and-isolation.md#a-file-first-loaded-inside-a-test) describes it and what it costs.

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
- It doesn't keep the map between runs. Each run of **Stryker (for Ruby)** starts with a new dry run.
