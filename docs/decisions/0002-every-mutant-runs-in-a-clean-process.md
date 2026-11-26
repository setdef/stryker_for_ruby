---
status: proposed
date: 2026-11-26
deciders: "The project's architect, an AI agent, chose the mechanism. It works within the owner's scope rulings: Linux, macOS, and Windows in the first release, with correct results preferred over fast ones ([#4](https://github.com/setdef/stryker_for_ruby/issues/4)), and Minitest and RSpec adapters ([#5](https://github.com/setdef/stryker_for_ruby/issues/5)). The rulings on the gem's name ([#1](https://github.com/setdef/stryker_for_ruby/issues/1)), the executable ([#2](https://github.com/setdef/stryker_for_ruby/issues/2)), and the configuration file ([#3](https://github.com/setdef/stryker_for_ruby/issues/3)) don't bear on this decision."
---

# Every mutant runs in a clean process

## Context and Problem Statement

**Stryker (for Ruby)** runs the project's tests once for each mutant. Each run loads the same instrumented code, which holds every mutant behind a switch, and sets which mutant is active. A test can leave state behind, such as a changed global, constant, class variable, or environment variable, so a run that starts from another run's leftovers can report a result that depends on what ran before it.

The measurements in [#4](https://github.com/setdef/stryker_for_ruby/issues/4) found that a reused worker carries that state into every later run, on Linux, macOS, and Windows, while forked and freshly started processes always start clean. Forking from a parent that has loaded the code and tests costs about 0.6 ms on Linux and about 2 ms on macOS. A fresh process costs 81 to 1,035 ms, depending on the system and the suite. Windows has no `fork`: `Process.fork` raises `NotImplementedError`. Static mutants, whose code runs only while a file loads, take effect only when the mutant is active before the code loads.

How does each mutant run get a clean process on each system?

## Decision Drivers

* Correct results come before fast ones ([#4](https://github.com/setdef/stryker_for_ruby/issues/4)).
* Windows is supported in the first release ([#4](https://github.com/setdef/stryker_for_ruby/issues/4)), and it has no `fork`.
* A static mutant has to be active before the project's code loads.
* Every run pays its start cost, multiplied by the number of mutants.

No other driver was recorded.

## Considered Options

1. **Fork where it exists, fresh processes elsewhere, and no reuse.** On Linux and macOS, a parent that has loaded the instrumented code and the tests forks one child per mutant run. The child sets the active mutant, runs only the tests that reached it, reports over a pipe, and calls `exit!`. On Windows, a pool of fresh processes loads the code and waits; each process receives one mutant ID over a pipe, runs once, and exits. A static mutant runs in a fresh process with the mutant ID in its environment before load, on every system. No process is reused for a second run by default.
2. **Reused workers,** as StrykerJS runs them: long-lived processes that switch the active mutant between runs.
3. **A fresh process for every run,** on every system.

## Decision Outcome

Chosen: option 1, because the owner ruled for correct results over fast ones in [#4](https://github.com/setdef/stryker_for_ruby/issues/4), and fork gives the same clean start as a fresh process at about 1% of its cost where the system has it. Option 2 lost because a reused worker carries state from one run into the next, as measured in [#4](https://github.com/setdef/stryker_for_ruby/issues/4). Option 3 lost because fork is far cheaper on Linux and macOS: 0.6 ms against 81 to 298 ms on Linux, and about 2 ms against 215 to 483 ms on macOS, for the two suites measured. How it works is in [docs/design/loading-and-isolation.md](../design/loading-and-isolation.md).

Confidence: the probes show that option 1 works. A forked child saw its mutant while the parent stayed unchanged, a Minitest test failed in the child with its mutant active and passed with none, and a fresh Windows process with the mutant ID in its environment failed the same test. A static mutant set active after load had no effect, and one set in the environment of a fresh process did. A recorded comparison in [#4](https://github.com/setdef/stryker_for_ruby/issues/4) supports "better": a reused worker started dirty on all three systems where fork and fresh processes started clean, and the table there gives each option's start cost. Unproven: the Windows pool hasn't been built or timed. The #4 figure for spreading fresh processes over 8 cores is an estimate, not a measurement. Nobody has timed fork from a Rails-sized parent beyond a 750 MB heap, and no probe has tried a parent that runs background threads.

### Consequences

* Good, because every run starts from the same state, so a mutant's result doesn't depend on which runs came before it.
* Good, because a forked child inherits the loaded code and tests, so a run on Linux or macOS pays no load time.
* Bad, because every Windows run pays the project's load time. For 1,000 runs, [#4](https://github.com/setdef/stryker_for_ruby/issues/4) puts that at about 7 minutes for a suite like Liquid's and about 17 minutes for one like Asciidoctor's, with the runs one after another.
* Bad, because a static mutant costs a fresh process on every system, Linux and macOS included.
* Bad, because the cost of a fork grows with the parent's heap: about 9 to 19 ms with a 750 MB heap.
* Bad, because a child ends with `exit!`, so `at_exit` handlers, the project's included, never run in a mutant run.
* Bad for maintainers, because there are two isolation adapters to build, test, and keep working, and Windows needs separate code for time limits and for killing a stuck run. CI has no Windows job.
* Neutral, because option 2 is ruled out only as the default.

### Confirmation

Nothing checks this decision yet. When the isolation adapters exist, the contract tests in `stryker/testing` check that a run which changes a global, a constant's contents, a class variable, or an environment variable, or which defines a constant, leaves the next run unchanged, against each adapter. No CI job runs on Windows, so nothing checks the Windows adapter on Windows until one does.

## More Information

[#4](https://github.com/setdef/stryker_for_ruby/issues/4) holds the measurements and the owner's ruling. Revisit this decision if Windows gains `fork` in Ruby, or if a way to reset a process between runs is shown to leave no state behind.
