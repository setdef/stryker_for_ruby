# Configuration

This page lists every option of **Stryker (for Ruby)**: its name, its type, its default, and what it does. A run works on Linux and macOS, with Minitest. On Windows, where Ruby has no `fork`, a run isn't built yet: `stryker run` checks the configuration and then stops with status 2. The options and their defaults are those of [StrykerJS](https://stryker-mutator.io/docs/stryker-js/configuration/), except `mutate` and `testRunner`, whose defaults are for Ruby, and the options that mean nothing in Ruby, which are left out.

## Where options come from

An option takes its value from the first of these that gives one:

1. The command line.
2. The configuration file.
3. The default.

A value on the command line replaces the file's value for that option. A list, such as `mutate`, is replaced as a whole, never added to.

### The configuration file

A configuration file is JSON or YAML, and holds one object whose keys are option names. Nested options have a parent key: `thresholds` holds `high`, `low`, and `break`, and `mutator` holds `excludedMutations`. This page writes a nested option with a dot, as `thresholds.break`. In a file, either spelling works: a `thresholds` object with a `break` key, or the key `"thresholds.break"`. A file that gives one option in both spellings is an error, because it doesn't say which value to use.

**Stryker (for Ruby)** looks for these files in the project's root, in this order:

1. `stryker.config.json`
2. `stryker.config.yml`

With neither file, `stryker run` uses the defaults and the command line. With both, it stops, because it can't tell which one you mean: delete one, or name the one to read, as in `stryker run stryker.config.yml`. A file you name takes the place of both. A named file whose name doesn't end in `.json`, `.yml`, or `.yaml` is an error, and so is one that doesn't exist.

A JSON file can't start with a byte-order mark (BOM), because JSON doesn't allow one. A file that does is an error that says so: save it as UTF-8 without a BOM. A YAML file may start with one.

A configuration file's bytes must be valid UTF-8. A JSON or YAML file that holds a byte that isn't is an error, and the one for a JSON file gives the line of the first such byte. **Stryker (for Ruby)** refuses the file instead of reading each bad byte as U+FFFD, because a `mutate` pattern that holds U+FFFD matches no file, so the pattern would select fewer files than you wrote it for, with no error.

An empty YAML file has no options. A YAML file may hold only strings, numbers, booleans, null, lists, and maps. A date, a symbol, an alias, or a tag for a Ruby class is an error, because the file comes from the project and loading it must never run code.

### The command line

The `stryker` command takes these words:

| Command line | What it does |
| - | - |
| `stryker run [configFile]` | Checks the configuration, then runs mutation testing. |
| `stryker help [command]` | Writes the overview of the commands, or the help of one command, to standard output. |
| `stryker -h`, `stryker --help` | The same as `stryker help`. After `run`, `-h` or `--help` writes the help of `stryker run` and does nothing else. |
| `stryker --version` | Writes the version to standard output. |
| `stryker` with no words | Writes the overview to standard error, and exits with status 2. |

There is no `-v`, because other tools use it for both "verbose" and "version". A command that doesn't exist is an error that suggests the nearest command and exits with status 2:

```text
Unknown command "hlep". Did you mean "help"? Run "stryker help" for the commands.
```

`stryker run` reads the file and the flags and runs every check. With no problem, it finds the files that [`mutate`](#mutate) selects, makes their mutants, runs every test once with no mutant active, and then runs the tests against each mutant, each run in a process of its own, up to [`concurrency`](#concurrency) at once. Each reporter in the [`reporters`](#reporters) list writes the results when the last mutant's run ends.

On Windows, where Ruby has no `fork`, the command stops after the checks, writes this to standard error, and exits with status 2:

```text
A run on Windows isn't built yet: Stryker (for Ruby) runs each runtime mutant in a process forked from one that loaded the project, and Windows has no fork.
```

#### Flags

Every option is also a flag. The flag is the kebab-case form of the option's name, with its dots kept: `testRunner` is `--test-runner`, `timeoutMS` is `--timeout-ms`, and `mutator.excludedMutations` is `--mutator.excluded-mutations`. `-m` is short for `--mutate` and `-c` for `--concurrency`. A flag takes its value as the next word or after an equals sign, so `--thresholds.break 80` and `--thresholds.break=80` are the same. Flags and the configuration file may come in any order. A flag must be written in full: `--test` is not short for `--test-runner`.

Each flag writes its value as text, and the command turns the text into the type of the option:

| Type of the option | Text of the flag |
| - | - |
| list of strings (`mutate`, `reporters`, `mutator.excludedMutations`) | Items separated by commas, such as `--reporters clear-text,json`. A comma inside braces is part of the item, so `--mutate "lib/{a,b}/**/*.rb"` is one pattern. The flag adds to its list each time it appears, and empty text gives an empty list. |
| number (`timeoutMS`, `timeoutFactor`, `dryRunTimeoutMinutes`) | `80` is a whole number, and `80.5` or `1e3` is a decimal. |
| whole number (`thresholds.high`, `thresholds.low`) | A whole number such as `80`. `80.0` counts as one, and a decimal such as `80.5` is an error. |
| `concurrency` | A whole number such as `4`, or a percentage such as `50%`. |
| `thresholds.break` | A number, or `none` to clear a `thresholds.break` that the file sets. |
| boolean (`incremental`) | `--incremental` for true and `--no-incremental` for false. |
| string (`testRunner`) | The text as it is. |

Text that isn't of the type, such as `--timeout-ms soon`, is an error like a wrong type in the file, and its line gives the flag.

A flag that doesn't exist is an error that suggests the nearest flag, and so is a flag that lacks its value:

```text
Unknown flag --test-runnr. Did you mean --test-runner? Run "stryker help run" for the flags.
The flag --test-runner needs a value. Run "stryker help run" for the flags.
```

`stryker run` takes at most one configuration file.

#### Exit statuses

| Status | When |
| - | - |
| 0 | The run finished, and its score is at or above `thresholds.break`, or no break is set, or no mutant counted toward the score. `stryker help`, `stryker -h`, `stryker --help`, `stryker --version`, and `stryker run -h` also exit with 0 when they have written their text. |
| 1 | The run finished, and its score is below `thresholds.break`. |
| 2 | The run couldn't finish: a command line, flag, or configuration error, an ERB template that `mutate` selects, a dry run that failed, a run on Windows, or an error in **Stryker (for Ruby)** itself. An error in **Stryker (for Ruby)** writes its backtrace and the address to report it at. |
| 128 plus the signal's number | A signal ended the run: 130 for Ctrl-C (`INT`) and 143 for `TERM`. The command writes `Stopped by INT.` or `Stopped by TERM.` to standard error. It ends every process that the run started and deletes its temporary files before it exits. A second signal stops that cleanup and leaves the temporary files. |

A dry run fails, and no mutant runs, when a test fails with no mutant active, when the tests take longer than [`dryRunTimeoutMinutes`](#dryruntimeoutminutes), or when a file that `mutate` selects loaded without its mutants, as it can when another library loads Ruby files itself. The message says which test failed, or what went wrong.

#### Output

Help, the version, and the report of a run go to standard output. Errors go to standard error, and so does the overview that `stryker` writes when it has no words, so `stryker run > report.txt` holds the report and nothing else. The output of the project's tests goes to files in a temporary folder, and to neither stream.

Output has no color when standard output isn't a terminal, when the `NO_COLOR` environment variable has a value, when `TERM` is `dumb`, and with `--no-color`. A report that goes to a file has no color.

## Checks

Before it does anything else, `stryker run` checks every option in the file and on the command line, including a file option that a flag replaces. A run with a problem stops before it reads any file to mutate. The message has one line for each problem, and each line says which file or flag the value came from. The command exits with status 2.

- **An option that doesn't exist** is an error that suggests the nearest name:

  ```text
  Unknown option "timeoutMs" in stryker.config.json. Did you mean "timeoutMS"?
  ```

- **A value of the wrong type** is an error that gives the option, the type it takes, and the value:

  ```text
  "concurrency" in stryker.config.json takes a whole number of 1 or more, or a percentage of the processors such as "50%", but its value is 0.
  ```

- **An option that a file gives twice**, in both spellings of a nested option, is an error that gives both keys:

  ```text
  "thresholds.break" in stryker.config.json is given twice, as "break" inside "thresholds" and as "thresholds.break". Give it once.
  ```

- **A `thresholds.high` below `thresholds.low`** is an error that gives both options and where each value came from. An option that no file or flag sets counts with its default, so `thresholds.high` of `50` alone is below the default `thresholds.low` of `60`. Equal values are fine ([`thresholds.high`](#thresholdshigh)).
- **A name in `mutator.excludedMutations` that no mutator has** is an error that lists the valid names ([`mutator.excludedMutations`](#mutatorexcludedmutations)).
- **A pattern in `mutate` that resolves outside the project's root** is an error ([`mutate`](#mutate)).
- **A pattern in `mutate` with a NUL byte** is an error, because no file name holds one. In JSON, a NUL byte is the escape `\u0000`.

The checks read the type of `testRunner` and `reporters`. Once they pass, and before it reads any file to mutate, the run checks that a test runner and each reporter with those names exist ([`testRunner`](#testrunner), [`reporters`](#reporters)).

## Options

| Option | Type | Default |
| - | - | - |
| [`mutate`](#mutate) | list of strings | `lib/**/*.rb` and `app/**/*.rb`, with `.erb` too, leaving out test files |
| [`testRunner`](#testrunner) | string | `minitest` when the project has a `test/` folder, `rspec` when it has a `spec/` folder |
| [`reporters`](#reporters) | list of strings | `clear-text`, `progress`, `html` |
| [`concurrency`](#concurrency) | whole number, or a percentage string | the number of logical processors, less one when there are more than four |
| [`thresholds.high`](#thresholdshigh) | whole number from 0 to 100 | `80` |
| [`thresholds.low`](#thresholdslow) | whole number from 0 to 100 | `60` |
| [`thresholds.break`](#thresholdsbreak) | number from 0 to 100, or null | none |
| [`timeoutMS`](#timeoutms) | number of 0 or more | `5000` |
| [`timeoutFactor`](#timeoutfactor) | number of 0 or more | `1.5` |
| [`dryRunTimeoutMinutes`](#dryruntimeoutminutes) | number of 0 or more | `5` |
| [`mutator.excludedMutations`](#mutatorexcludedmutations) | list of strings | none |
| [`incremental`](#incremental) | boolean | `false` |

### `mutate`

The files to mutate: a list of glob patterns, relative to the project's root. A pattern that starts with `!` leaves files out, as in `"!lib/generated/**/*.rb"`.

The default is `lib/**/*.rb`, `app/**/*.rb`, `lib/**/*.erb`, and `app/**/*.erb`, with the files below left out:

- the files in any `test/` or `spec/` folder, at any depth;
- the files whose names end in `_test.rb` or `_spec.rb`.

A mutant in a test file changes the test that judges it, so the default leaves test files out. A pattern that you write replaces the default and can match a test file. Nothing stops it.

A pattern that resolves outside the project's root is an error, such as `../shared/lib/**/*.rb`, or an absolute path to a folder that isn't inside the root. A pattern that goes up and comes back, such as `lib/../app/**/*.rb`, resolves inside the root and is fine. The check reads the text of the pattern, so it doesn't expand `{a,b}` alternatives. A `~` is an ordinary character, as it is in a glob, so `~/lib/**/*.rb` is a folder named `~` inside the root.

The patterns apply in order, as StrykerJS applies them: a pattern adds the files it matches, and a pattern that starts with `!` takes away, from the files that the patterns before it added, those it matches. So `["lib/**/*.rb", "!lib/generated/**/*.rb", "lib/generated/schema.rb"]` mutates `lib/generated/schema.rb` and no other file in `lib/generated`. A folder is never selected, whatever its name.

An empty list selects no file.

**Stryker (for Ruby)** mutates Ruby files only. When a pattern matches an ERB template, a file whose name ends in `.erb`, the run stops before it reads any file, with an error that gives the template's path. The default patterns select the templates in `lib` and `app`, so a project that has any needs a pattern that leaves them out, such as `"!**/*.erb"`.

### `testRunner`

The name of the test runner for the project's tests. The one test runner is `minitest`, for Minitest 6. Any other name, `rspec` included, stops the run before it reads any file, with an error that gives the names it takes:

```text
Stryker (for Ruby) has no test runner named "rspec". The testRunner option takes "minitest".
```

With no value, the project's folders choose it: `minitest` when the project has a `test/` folder, and `rspec` when it has a `spec/` folder. A project with neither, or with both, is an error that asks you to set `testRunner` in the configuration file or pass `--test-runner`. A file called `test` isn't a `test/` folder.

### `reporters`

A list of reporter names. The default is `clear-text`, `progress`, and `html`, as in StrykerJS. The reporters are `clear-text` and `json`. A name that isn't one of them stops the run before it reads any file, so a run with the default stops too, because the default holds `progress` and `html`:

```text
Stryker (for Ruby) has no reporter named "progress" or "html". The reporters option takes "clear-text" and "json".
```

Set the option to the reporters you want, as in `stryker run --reporters clear-text,json`. Each reporter runs once, even when the list holds its name twice.

#### The `clear-text` reporter

Writes a summary of the run to standard output, once, when the run ends. It follows the text of StrykerJS's `clear-text` reporter, without emojis. A run that stops before it ends writes nothing. The summary has three parts:

1. A description of each mutant that no test caught, which has the status `Survived` or `NoCoverage`. It gives the status and the mutator, the file with the line and column of the mutant, the original lines with `-` before each, and the lines with the mutant in place with `+` before each. For a survivor, it then lists the first three tests that ran against the mutant and counts the rest, as `and 2 more tests!`. For a static survivor, it says `Ran all tests for this mutant.` A mutant that a test killed, or that ended with an error or a timeout, gets no description.
2. The line `Ran 1.25 tests per mutant on average.`, with the number of tests that finished, over all mutants, divided by the number of mutants. For a run with no mutants, the number is `NaN`.
3. A table of the [mutation score](https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/) of all files, of each folder, and of each file, with the counts of killed, timed-out, surviving, uncovered, and errored mutants. The folders that every file shares are left out of the names. Folders come before files, and each group is in the order of the names. The `total` column is the score of all valid mutants, and the `covered` column leaves out the mutants that no test reached. A score is `n/a` when no mutant is valid.

The reporter paints the file and location, the lines with `-` and `+`, and each score with ANSI colors: a score at or above [`thresholds.high`](#thresholdshigh) is green, one at or above [`thresholds.low`](#thresholdslow) is yellow, a lower one is red, and `n/a` is gray. It paints nothing when standard output isn't a terminal, when the environment sets `NO_COLOR`, when `TERM` is `dumb`, and with `--no-color`.

#### The `json` reporter

Writes the run's report to `reports/mutation/mutation.json` in the project's root, once, when the run ends. It creates the folders, and replaces the report of an earlier run. A run that stops before it ends leaves the file as it was. When a file that has a mutant, or a test file, no longer exists at the end of the run, the reporter stops with that error and writes no report.

The report is one line of JSON in the [mutation testing report schema](https://github.com/stryker-mutator/mutation-testing-elements/tree/master/packages/report-schema) (schema version `1.0`) that the Stryker tools share, so any viewer of that schema reads it. `files` holds each file that has a mutant, by its path from the project's root, with its language, `ruby`, its source, and its mutants. `testFiles` holds each test file by its path, with its source and its tests: each test's `id`, `name`, and `location`. A test with no file goes under the empty name, with no source. A field with no value is left out of a mutant or a test.

| Field of a mutant | What it holds |
| - | - |
| `id` | The mutant's number in the run, as a string. |
| `mutatorName` | The name of the mutator that made the mutant. |
| `replacement` | The text that replaces the range in `location`. |
| `location` | The range in the file that the mutant replaces: `start` and `end`, each with a `line` and a `column` counted from 1. `end` is just after the range. Columns count UTF-16 code units, as JavaScript counts the index of a character in a string, so an emoji takes two columns. |
| `status` | `Killed`, `Survived`, `NoCoverage`, `CompileError`, `RuntimeError`, `Timeout`, or `Ignored`. |
| `statusReason` | Why the mutant has that status, for a status that has a reason. |
| `coveredBy` | The IDs of the tests that reached the mutant. |
| `killedBy` | The ID of the test that killed the mutant. |
| `testsCompleted` | How many tests finished in the mutant's run. |
| `duration` | The run's time in milliseconds. |
| `static` | Whether the mutant was static, so its run was a fresh process with the mutant active before any file loaded. |

### `concurrency`

How many project processes run at once. It takes a whole number of 1 or more, or a percentage string from `"0%"` to `"100%"` that is a share of the logical processors. A percentage rounds half up, as StrykerJS rounds it, and never gives fewer than 1. On a machine with 8 processors, `"50%"` is 4, `"100%"` is 8, and `"1%"` is 1.

With no value, a machine with 1 to 4 processors uses that many, and a machine with more uses one fewer: 7 on a machine with 8.

A whole number may be more than the number of processors. Each project process loads your code, so more processes use more memory.

### `thresholds.high`

The mutation score, as a percentage, at or above which the score counts as high. It takes a whole number from 0 to 100, such as `80`. `80.0` counts as a whole number, and the configuration holds it as `80`. A fraction such as `82.5` is an error, because the JSON report holds this threshold as an integer and a report with a fraction would fail its schema. The default is `80`. Reports use it to color the score. It can't be below `thresholds.low`.

### `thresholds.low`

The mutation score, as a percentage, below which the score counts as low. It takes a whole number from 0 to 100, such as `60`. A fraction is an error, for the reason that `thresholds.high` gives. The default is `60`. Reports use it to color the score. It can't be above `thresholds.high`.

### `thresholds.break`

The mutation score, as a percentage, below which the run exits with status 1. It takes any number from 0 to 100, such as `80.5`, or null. Unlike `thresholds.high` and `thresholds.low`, it may be a fraction, because it never reaches the report. The default is null, which sets no limit. `0` is a limit that no score is below. Set it in CI to fail a build when the tests get weaker: `stryker run --thresholds.break 75`.

### `timeoutMS`

The milliseconds that a run's time limit adds to the dry-run time of its tests. It takes any number of 0 or more, such as `2500.5`. The default is `5000`. Raise it on a busy machine, so that a slow run isn't taken for an infinite loop.

### `timeoutFactor`

How many times the dry-run time of a run's tests a run may take, before `timeoutMS` is added. It takes any number of 0 or more. The default is `1.5`. Raise it when mutants make the code slower without making it loop forever. Use `timeoutMS` for a mutant that loops forever.

A run's limit is the dry-run time of the run's tests, times `timeoutFactor`, plus `timeoutMS`, plus the dry run's overhead, rounded up to a whole millisecond, as in StrykerJS:

```text
limit = dry-run time of the run's tests × timeoutFactor + timeoutMS + overhead
```

A run of a mutant that tests reach has the tests that passed and reached it. A run of a static mutant has every test that passed in the dry run. The overhead is the dry run's time from the start of its first test to the end of its last, less the sum of its tests' times: the test runner's time between tests. With the defaults, a mutant reached by two tests that took 100 ms and 20 ms, in a dry run whose overhead was 30 ms, has a limit of 1.5 × 120 + 5000 + 30 = 5210 ms. A run that passes its limit gives its mutant the status `Timeout`.

### `dryRunTimeoutMinutes`

How many minutes the dry run's tests may take, from the start of the first test to the end of the last. It takes any number of 0 or more, such as `0.5`. The default is `5`, as in StrykerJS. A dry run that takes longer fails the run, with an error that names this option. Raise it for a test suite that takes longer than 5 minutes to run once.

### `mutator.excludedMutations`

The names of the mutators that make no mutant, such as `"BooleanLiteral"`. The default is an empty list.

A name matches a mutator's name exactly, with its letter case: `Equality` is the name of Stryker.NET's mutator, and the name here is `EqualityOperator`. A name that no mutator has is an error that lists the valid names. StrykerJS ignores such a name, so a misspelled name would leave its mutator running, and the run stops here instead. [Mutators](contributors/design/mutators.md#the-catalog) lists the names.

### `incremental`

A boolean. The default is `false`.

## Example files

The same configuration in each format: the models and the services, except the legacy services, with RSpec as the test runner, half of the processors for `concurrency`, a break score of 75, and two excluded mutators:

```json
{
  "mutate": ["app/models/**/*.rb", "app/services/**/*.rb", "!app/services/legacy/**/*.rb"],
  "testRunner": "rspec",
  "concurrency": "50%",
  "thresholds": { "high": 90, "low": 70, "break": 75 },
  "timeoutMS": 10000,
  "timeoutFactor": 2,
  "mutator": { "excludedMutations": ["BooleanLiteral", "EqualityOperator"] }
}
```

```yaml
mutate:
  - app/models/**/*.rb
  - app/services/**/*.rb
  - "!app/services/legacy/**/*.rb"
testRunner: rspec
concurrency: 50%
thresholds:
  high: 90
  low: 70
  break: 75
timeoutMS: 10000
timeoutFactor: 2
mutator:
  excludedMutations:
    - BooleanLiteral
    - EqualityOperator
```

In YAML, quote a pattern that starts with `!`, because `!` starts a tag. The `"!app/services/legacy/**/*.rb"` above is quoted for that reason. `concurrency: 50%` needs no quotes: `%` starts a directive only at the start of a line.

A flag over this file's `thresholds.break`:

```sh
stryker run --thresholds.break 80
```
