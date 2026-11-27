# Test runners

This page specifies the adapters of the `_TestRunner` port: how each one lists a project's tests, runs a chosen set of them one at a time in a project process, and turns what the framework records into a `TestResult`, and which parts of the framework each one depends on. [The ports](architecture.md#the-ports) says where the port fits, and the terms are defined in [Loading and isolation](loading-and-isolation.md#terms).

## What every adapter does

An adapter loads in a project process, so it uses only the standard library and the test framework, which the project already has. It refers to the framework only after the project's files have loaded it, so the project's bundle chooses the framework's version ([ADR 0003](../decisions/0003-the-processes-that-load-the-projects-code-load-only-stryker-for-rubys-runtime-which-depends-on-nothing-outside-the-standard-library.md)).

- **`load_tests`** loads the project's test helper and test files, and returns every test they define, without running any. Every process that loads the same files gets the same tests, in the same order, with the same IDs, because each mutant run is given its tests by the IDs from the dry run.
- **`run`** runs the tests it is given, in that order, one at a time. It tells the observer when each test starts and when it finishes, so the hit recorder makes each test's bucket current while that test runs ([Coverage](coverage.md#hits)). With `bail` true, it stops after the first test that fails, because one failure kills the mutant.
- **A test's time** is measured with `Process.clock_gettime(Process::CLOCK_MONOTONIC)`, in milliseconds, so a change to the system clock during a run doesn't change it.

The [contract tests](architecture.md#contract-tests) hold every adapter to this, and [`Stryker::Testing::TestRunnerContract`](../../../sig/stryker/testing/test_runner_contract.rbs) says what they check.

## Minitest

`Stryker::TestRunners::MinitestRunner` is the adapter for Minitest 6. Minitest has no public way to run one chosen test, so the adapter depends on some of Minitest's internals. Minitest 6 has no built-in way to stop at the first failure either, so the adapter supplies one for `bail`. [Ways to run a chosen test](#ways-to-run-a-chosen-test) compares the ways that were tried.

### Loading the tests

The adapter's constructor, its defaults, and the tests' IDs, files, and locations are in the [RBS documentation of `MinitestRunner`](../../../sig/stryker/test_runners/minitest_runner.rbs). This section keeps the reasons behind them.

Everything `load_tests` returns must be the same in every process, because each mutant run is given its tests by the IDs from the dry run. So the helper and the test files load in the order of their paths, which fixes the order that the classes are defined in, and so the order of the tests. An ID is the class's name and the method's name, as Minitest prints a test, and it must stand for exactly one test. The adapter raises `Stryker::UnsupportedError` for a test class with tests and no name, and for two tests with the same ID, such as two `describe` blocks with the same name, instead of giving a test an ID that stands for two tests, or for none that another process could find.

`Minitest::Test.runnable_methods` seeds Ruby's random numbers with `Minitest.seed`, and raises `TypeError` while it is nil. `Minitest.run` sets it, and the adapter never calls `Minitest.run`, so the adapter sets it to 0 when the project hasn't set it. A class in Minitest's default random order seeds them each time `run_suite` runs it, so each of its tests starts with the same random numbers in every process.

### Why the adapter empties Minitest's list of classes

`require "minitest/autorun"`, which most projects' helpers run, registers an `at_exit` block that runs every class in `Minitest::Runnable.runnables`. A project process that exits normally runs it.

> [!WARNING]
> In a probe that loaded a project, ran some of its tests, and exited normally, the `at_exit` block ran the whole suite again, the tests that weren't chosen included, outside any test's bucket. With the list empty, it ran no test.

The block still runs, and prints Minitest's summary of a run of 0 tests to standard output.

### Running one test

The adapter runs a test at the level where Minitest runs a class when you pass `--include`: a class's `run_suite`, with a filter that matches only the test's method. Every hook that the project or a plugin adds runs as it would there, whether it wraps a class's run (minitest-hooks' `before_all` and `after_all`), changes a class's `run` (`abstract_test_case!`, which is why an abstract class runs nothing), or wraps a test's `run`, setup, or teardown (minitest-retry). [Ways to run a chosen test](#ways-to-run-a-chosen-test) shows what each other level lost.

A class that calls `parallelize_me!` hands its tests to `Minitest.parallel_executor` instead of running them. Minitest's executor runs them only in threads that `Minitest.run` starts, so such a test would run later or never, outside its turn and its bucket. For the one test, the adapter puts an executor in its place that runs each job at once, in the same thread.

Minitest records more than one result during a test: one for the test, and one for each hook around the class that fails, under the hook's name. A reporter that kept only the test's result would miss a failing `before_all`, so the adapter's reporter keeps every result, and a test fails when any of them did. Minitest counts a result by its first failure, so a test that skips and then raises in `teardown` is skipped.

An exception that Minitest lets through, such as `SystemExit` from a test that calls `exit`, leaves `run` at once, after the observer heard the test start and before it hears the test finish. [How a run's outcome becomes a status](loading-and-isolation.md#how-a-runs-outcome-becomes-a-status) says how the orchestrator judges such a run.

### Retries

On Minitest 6, minitest-retry 0.3.1 prepends a `run` to `Minitest::Test` that runs the test again after a failure. Every attempt happens inside the one call, between the observer's start and finish, so every attempt's hits land in the test's one bucket. The test's result is its last attempt's: a test that fails and then passes has passed.

### Ways to run a chosen test

A probe ran each way against one project, with every test noting each time it ran: tests that pass, fail an assertion, raise in the test and in `teardown`, and skip; an abstract class and its subclass; a `parallelize_me!` class; a `describe` block; a minitest-retry test that fails once; and a minitest-hooks class with `before_all`. It ran every test but one, then exited normally. It used Minitest 6.1.0, minitest-retry 0.3.1, and minitest-hooks 1.5.4, on Ruby 4.1-dev, and the last way on Ruby 4.0.10 as well, on macOS.

| Way | Abstract class's test | `parallelize_me!` test | minitest-hooks test | Results |
| - | - | - | - | - |
| `klass.new(name).run`, the instance's `run` | Ran, though Minitest never runs it | Ran in its turn | Raised `FrozenError` | Minitest's result for the test only |
| `Runnable.run(class, name, reporter)`, the class's `run` | Didn't run | Didn't run in its turn | Raised `FrozenError` | Every result, through the reporter |
| `Minitest.run` with `--include` | Didn't run | Ran, in the executor's threads | Ran | Only `true` or `false`, and Minitest's whole report on standard output each time |
| `run_suite` with a filter, and the stand-in executor | Didn't run | Ran in its turn | Ran | Every result, through the reporter |

Every way gave the other tests the same results. minitest-retry, which runs any failing test again, ran each failing test four times in every way. `Minitest.run` needs the list of classes that `minitest/autorun` runs at exit, so with it the `at_exit` block ran the whole suite again. `Minitest.run` also prints a report, starts and stops the parallel executor, and parses its arguments on every call. The adapter uses the last way.

The adapter depends on these parts of Minitest 6, which are in Minitest's documentation unless the list says otherwise:

- `Minitest::Runnable.runnables`, which it reads and empties;
- `runnable_methods` on each class;
- `Minitest::Runnable.run_suite(reporter, options)`, with a `Regexp` in `options[:include]` that matches the method's name;
- `Minitest::Runnable.run(klass, method_name, reporter)`;
- a reporter's `prerecord`, `record`, and `passed?`, and a result's `name` and `result_code`;
- a result's `to_s`, for the message, which Minitest marks as internal;
- `Minitest.seed` and `Minitest.parallel_executor`;
- the job `[klass, method_name, reporter]` that a `parallelize_me!` class hands the parallel executor, which Minitest marks as internal.

### What the Minitest adapter doesn't do

- It doesn't run Minitest's reporters or plugins' reporters, because it never calls `Minitest.run`, so a plugin's report isn't written.
- It doesn't run tests in parallel, even in a class that calls `parallelize_me!`.
- It doesn't list a test class that a test defines while it runs.
- It doesn't give a test's location.
