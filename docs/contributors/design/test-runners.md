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

The adapter takes the project's root, the path of its test helper, the patterns of its test files, and the folders to put on `$LOAD_PATH`. The defaults are `test/test_helper.rb`, and `Minitest::TestTask`'s defaults for the rest: the files `test/**/test_*.rb` and `test/**/*_test.rb`, and the folders `lib`, `test`, and the root. `load_tests`:

1. puts the folders on `$LOAD_PATH`, as `rake test` does;
2. requires the helper, when the file exists, and then each test file, in the order of their paths, so a file that each test file also requires loads once;
3. lists every test of every class in `Minitest::Runnable.runnables` whose `runnable_methods` returns at least one method name, in the order the classes were defined, each class's tests sorted by name;
4. empties `Minitest::Runnable.runnables`.

A test's ID is its class's name and its method's name, `Shop::DiscountTest#test_rate`, as Minitest prints a test in its output. A test in a `describe` block has the block's name as its class's name: `Shop::Discount#test_0001_applies the rate`. Its file is its method's file, from the project's root, and it has no location, because Ruby gives a method's first line and no end.

Two cases raise `Stryker::UnsupportedError`, because an ID must stand for exactly one test in every process: a test class with tests and no name, such as one made with `Class.new(Minitest::Test)` and never assigned to a constant, and two tests with the same ID, such as two `describe` blocks with the same name. A project whose files never load Minitest raises `NameError` for `Minitest`.

`Minitest::Test.runnable_methods` seeds Ruby's random numbers with `Minitest.seed`, and raises `TypeError` while it is nil. `Minitest.run` sets it, and the adapter never calls `Minitest.run`, so the adapter sets it to 0 when the project hasn't set it. A class in Minitest's default random order seeds them each time `run_suite` runs it, so each of its tests starts with the same random numbers in every process.

### Why the adapter empties Minitest's list of classes

`require "minitest/autorun"`, which most projects' helpers run, registers an `at_exit` block that runs every class in `Minitest::Runnable.runnables`. A project process that exits normally runs it.

> [!WARNING]
> In a probe that loaded a project, ran some of its tests, and exited normally, the `at_exit` block ran the whole suite again, the tests that weren't chosen included, outside any test's bucket. With the list empty, it ran no test.

The block still runs, and prints Minitest's summary of a run of 0 tests to standard output.

### Running one test

For each test, the adapter tells the observer that the test started, calls `run_suite` on the test's class with a filter that matches only the test's method, and tells the observer that it finished. That is how Minitest runs a class when you run it with `--include`, so every hook that the project or a plugin adds runs as it would there:

| Where the hook is | Examples | What the adapter does |
| - | - | - |
| Around a class's run (`run_suite`, `with_info_handler`) | minitest-hooks' `before_all` and `after_all` | Runs it around the one test. |
| A class's `run`, which runs one method | `abstract_test_case!`, `parallelize_me!` | Calls it, so an abstract class runs nothing. |
| A test's `run`, setup, and teardown | minitest-retry, a class's `setup` | Calls it. |

A class that calls `parallelize_me!` hands its tests to `Minitest.parallel_executor` instead of running them. Minitest's executor runs them only in threads that `Minitest.run` starts, so such a test would run later or never, outside its turn and its bucket. While a test runs, the adapter puts a stand-in in `Minitest.parallel_executor` that runs each test it's handed at once, in the same thread, with `Minitest::Runnable.run`, and puts the original back after.

The adapter passes `run_suite` a reporter it defines, `Outcome`, which keeps every result that Minitest records during the test. Minitest records one for the test, and one for a hook around the class that fails, under the hook's name. The test's result comes from all of them:

| What Minitest recorded | Status | Message |
| - | - | - |
| Any result that failed an assertion or raised, the test's or a hook's | `failed` | Each such result, as Minitest prints it |
| The test's result, with a skip as its first failure | `skipped` | none |
| Nothing for the test, as for a test of an abstract class | `skipped` | none |
| The test's result, passed | `passed` | none |

A test that skips and then raises in `teardown` is skipped, because Minitest counts a result by its first failure. An exception that Minitest lets through, such as `SystemExit` from a test that calls `exit`, leaves `run` at once, after the observer heard the test start and before it hears the test finish. [How a run's outcome becomes a status](loading-and-isolation.md#how-a-runs-outcome-becomes-a-status) says how the orchestrator judges such a run.

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
