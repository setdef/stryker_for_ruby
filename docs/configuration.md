# Configuration

This page lists every option of **Stryker (for Ruby)**: its name, its type, its default, and what it does. A run works on Linux and macOS, with Minitest. On Windows, where Ruby has no `fork`, a run isn't built yet: `stryker run` checks the configuration and then stops with status 2. The options and their defaults are those of [StrykerJS](https://stryker-mutator.io/docs/stryker-js/configuration/), with three exceptions. `mutate` and `testRunner` have defaults for Ruby. `minitest.testFiles` sets what only the Minitest test runner reads, as `tap.testFiles` does for StrykerJS's tap test runner. The options that mean nothing in Ruby are left out.

## Where options come from

An option takes its value from the first of these that gives one:

1. The command line.
2. The configuration file.
3. The default.

A value on the command line replaces the file's value for that option. A list, such as `mutate`, is replaced as a whole, never added to.

### The configuration file

A configuration file is JSON or YAML, and holds one object whose keys are option names. Nested options have a parent key: `thresholds` holds `high`, `low`, and `break`, `mutator` holds `excludedMutations`, and `minitest` holds `testFiles`. This page writes a nested option with a dot, as `thresholds.break`. In a file, either spelling works: a `thresholds` object with a `break` key, or the key `"thresholds.break"`. A file that gives one option in both spellings is an error, because it doesn't say which value to use.

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
| list of strings (`mutate`, `reporters`, `mutator.excludedMutations`, `minitest.testFiles`) | Items separated by commas, such as `--reporters clear-text,json`. A comma inside braces is part of the item, so `--mutate "lib/{a,b}/**/*.rb"` is one pattern. The flag adds to its list each time it appears, and empty text gives an empty list. |
| number (`timeoutMS`, `timeoutFactor`, `dryRunTimeoutMinutes`) | `80` is a whole number, and `80.5` or `1e3` is a decimal. |
| whole number (`thresholds.high`, `thresholds.low`) | A whole number such as `80`. `80.0` counts as one, and a decimal such as `80.5` is an error. |
| `concurrency` | A whole number such as `4`, or a percentage such as `50%`. |
| `thresholds.break` | A number, or `none` to clear a `thresholds.break` that the file sets. |
| boolean (`incremental`) | `--incremental` for true and `--no-incremental` for false. |
| string (`testRunner`) | The text as it is. |

Text that isn't of the type, such as `--timeout-ms soon`, is an error like a wrong type in the file, and its line gives the flag.

Text whose bytes aren't valid UTF-8, as a shell in a UTF-8 locale can pass, is an error too, and its line gives the flag. The exception is `--mutate`, whose patterns keep their bytes ([`mutate`](#mutate)).

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
| 2 | The run couldn't finish: a command line, flag, or configuration error, an ERB template that a `mutate` pattern of yours selects, a file that `mutate` selects and that doesn't parse, tests that failed to load, a dry run that failed, a run on Windows, or an error in **Stryker (for Ruby)** itself. An error in **Stryker (for Ruby)** writes its backtrace and the address of the forum to report it on. |
| 128 plus the signal's number | A signal ended the run: 130 for Ctrl-C (`INT`) and 143 for `TERM`. The command writes `Stopped by INT.` or `Stopped by TERM.` to standard error. It ends every process that the run started and deletes its temporary files before it exits. A second signal stops that cleanup and leaves the temporary files. |

The tests fail to load when your test helper or a test file raises while **Stryker (for Ruby)** loads it, as when a `Bundler.require` or the reading of a data file raises. The run stops before any test runs, exits with status 2, and writes no bug report, because the raising code is yours to fix. The message says that the tests failed to load, gives the class and message of what they raised, and gives the last lines of the standard error of the process that loaded them, when it wrote any:

```text
The project's tests failed to load, so no mutant can run. They raised:
JSON::ParserError: duplicate key "locale" at line 1 column 1
The end of the process's standard error:
Reading settings.json
```

A dry run fails, and no mutant runs, when a test fails with no mutant active, when the tests take longer than [`dryRunTimeoutMinutes`](#dryruntimeoutminutes), or when a file that `mutate` selects loaded without its mutants, as it can when another library loads Ruby files itself. The message says which test failed, or what went wrong.

#### Output

Help, the version, and the report of a run go to standard output. Errors go to standard error, and so does the overview that `stryker` writes when it has no words, and so does the [`progress`](#the-progress-reporter) reporter's text, so `stryker run > report.txt` holds the report and nothing else. The output of the project's tests goes to files in a temporary folder, and to neither stream.

Output has no color when its stream isn't a terminal, when the `NO_COLOR` environment variable has a value, when `TERM` is `dumb`, and with `--no-color`. Each stream is judged on its own: with standard output sent to a file and standard error on a terminal, the report has no color and the `progress` text has. A report that goes to a file has no color.

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
- **A pattern in `mutate` or `minitest.testFiles` that resolves outside the project's root** is an error ([`mutate`](#mutate), [`minitest.testFiles`](#minitesttestfiles)).
- **A pattern in `mutate` or `minitest.testFiles` with a NUL byte** is an error, because no file name holds one. In JSON, a NUL byte is the escape `\u0000`.
- **A pattern in `minitest.testFiles` whose bytes aren't valid UTF-8** is an error, because the test runner's options reach each project process as JSON, which holds only UTF-8.
- **A value whose bytes aren't valid UTF-8** is an error that gives the option and the value, for every option except `mutate`, such as `--test-runner` with the byte `\xFF`. Only a flag can hold such a value, because [a configuration file's bytes must be valid UTF-8](#the-configuration-file).

The checks read the type of `testRunner` and `reporters`. Once they pass, and before it reads any file to mutate, the run checks that a test runner and each reporter that you name exist ([`testRunner`](#testrunner), [`reporters`](#reporters)).

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
| [`minitest.testFiles`](#minitesttestfiles) | list of strings | `test/**/test_*.rb` and `test/**/*_test.rb` |

### `mutate`

The files to mutate: a list of glob patterns, relative to the project's root. A pattern that starts with `!` leaves files out, as in `"!lib/generated/**/*.rb"`.

The default is `lib/**/*.rb`, `app/**/*.rb`, `lib/**/*.erb`, and `app/**/*.erb`, with the files below left out:

- the files in any `test/` or `spec/` folder, at any depth;
- the files whose names end in `_test.rb` or `_spec.rb`.

A mutant in a test file changes the test that judges it, so the default leaves test files out. A pattern that you write replaces the default and can match a test file. Nothing stops it.

A pattern that resolves outside the project's root is an error, such as `../shared/lib/**/*.rb`, or an absolute path to a folder that isn't inside the root. A pattern that goes up and comes back, such as `lib/../app/**/*.rb`, resolves inside the root and is fine. The check reads the text of the pattern, so it doesn't expand `{a,b}` alternatives. A `~` is an ordinary character, as it is in a glob, so `~/lib/**/*.rb` is a folder named `~` inside the root.

The patterns apply in order, as StrykerJS applies them: a pattern adds the files it matches, and a pattern that starts with `!` takes away, from the files that the patterns before it added, those it matches. So `["lib/**/*.rb", "!lib/generated/**/*.rb", "lib/generated/schema.rb"]` mutates `lib/generated/schema.rb` and no other file in `lib/generated`. A folder is never selected, whatever its name.

An empty list selects no file.

The bytes of a pattern may be any bytes, because a file's name on Linux may hold any bytes: a pattern with the bytes of a file's name selects that file, so `mutate` accepts bytes that aren't valid UTF-8. Only a flag can give such a pattern. In a shell that reads `$'...'`, `stryker run --mutate $'lib/caf\xE9.rb'` selects the file named `caf` followed by the byte `E9`, which is `café.rb` in ISO-8859-1.

**Stryker (for Ruby)** mutates Ruby files only. The default patterns select the ERB templates in `lib` and `app`, files whose names end in `.erb`. A run with the default leaves them out, and writes one warning to standard error that says how many:

```text
Warning: this run leaves out 2 ERB templates, which the default mutate patterns select, because Stryker (for Ruby) doesn't mutate ERB templates. Name the files you want in mutate, as in --mutate "lib/**/*.rb", to choose your own.
```

A pattern that you give, in the file or on the command line, and that matches a template stops the run before it reads any file, with an error that gives the template's path. Leave templates out with a pattern such as `"!**/*.erb"`.

A file that a pattern selects and that isn't valid Ruby stops the run, with the file's path and the line of the first error that Prism, the Ruby parser, finds:

```text
lib/cart.rb doesn't parse as Ruby 4.0.0: unexpected end-of-input; expected an expression after the operator, on line 2. Fix the file, or leave it out of the mutate option.
```

The file is parsed as the Ruby that runs the command, so a file with syntax that only a newer Ruby has stops a run on an older one. The run exits with status 2 and writes no bug report, because the file is yours to fix.

### `testRunner`

The name of the test runner for the project's tests. The one test runner is `minitest`, for Minitest 6. Any other name, `rspec` included, stops the run before it reads any file, with an error that gives the names it takes:

```text
Stryker (for Ruby) has no test runner named "rspec". The testRunner option takes "minitest".
```

With no value, the project's folders choose it: `minitest` when the project has a `test/` folder, and `rspec` when it has a `spec/` folder. A project with neither, or with both, is an error that asks you to set `testRunner` in the configuration file or pass `--test-runner`. A file called `test` isn't a `test/` folder.

### `reporters`

A list of reporter names. The default is `clear-text`, `progress`, and `html`, as in StrykerJS. The reporters are `clear-text`, `progress`, and `json`. A name that you give, in the file or on the command line, and that isn't one of them stops the run before it reads any file:

```text
Stryker (for Ruby) has no reporter named "html". The reporters option takes "clear-text", "progress", and "json".
```

The default holds `html`, which isn't built. A run with the default leaves it out, runs `clear-text` and `progress`, and writes one warning to standard error before it reads any file:

```text
Warning: this run leaves out the default reporter "html", because Stryker (for Ruby) hasn't built it yet. Name the reporters you want, as in --reporters clear-text,json, to choose your own.
```

Set the option to the reporters you want, as in `stryker run --reporters clear-text,json`, to run `json` too and to stop the warning. Each reporter runs once, even when the list holds its name twice.

#### The `clear-text` reporter

Writes a summary of the run to standard output, once, when the run ends. It follows the text of StrykerJS's `clear-text` reporter, without emojis. A run that stops before it ends writes nothing. The summary has four parts:

1. The tree of the tests that the dry run found, under `All tests`. Each test file is under the folders that some test files share, and a folder that holds one folder or one file is on one line with it, as in `All tests/discount_test.rb` or `a/b`. Each test is under its file, in the order of the dry run, with what it did to the mutants: a green `✓` and `killed 2` for a test that killed two mutants, a blue `~` and `covered 3` for a test that reached three mutants and killed none, and a red `✘` and `covered 0` for a test that reached none. A test that has a location in the dry run's result shows it after its name, as `[line 3]`, and the `minitest` test runner gives none. A test with no file is under `All tests` and in no file. A run whose dry run found no test has no tree.

   ```text
   All tests/discount_test.rb
     ~ test_label (covered 2)
     ✓ test_rate (killed 4)
   ```

2. A description of each mutant that no test caught, which has the status `Survived` or `NoCoverage`. It gives the status and the mutator, the file with the line and column of the mutant, the original lines with `-` before each, and the lines with the mutant in place with `+` before each. For a survivor, it then lists the first three tests that ran against the mutant and counts the rest, as `and 2 more tests!`. For a static survivor, it says `Ran all tests for this mutant.` A mutant that a test killed, or that ended with an error or a timeout, gets no description.
3. The line `Ran 1.25 tests per mutant on average.`, with the number of tests that finished, over all mutants, divided by the number of mutants. For a run with no mutants, the number is `NaN`.
4. A table of the [mutation score](https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/) of all files, of each folder, and of each file, with the counts of killed, timed-out, surviving, uncovered, and errored mutants. The folders that every file shares are left out of the names. Folders come before files, and each group is in the order of the names. The `total` column is the score of all valid mutants, and the `covered` column leaves out the mutants that no test reached. A score is `n/a` when no mutant is valid. A mutant with the status `Ignored` is in no count and in neither score, and no part of the summary describes it. The `json` report lists it.

The reporter paints each test's mark and its name in the tree: the mark green, blue, or red as above, and the name, with its location when it has one, gray. It paints the file and location of each mutant, the lines with `-` and `+`, and each score with ANSI colors: a score at or above [`thresholds.high`](#thresholdshigh) is green, one at or above [`thresholds.low`](#thresholdslow) is yellow, a lower one is red, and `n/a` is gray. It paints nothing when standard output isn't a terminal, when the environment sets `NO_COLOR`, when `TERM` is `dumb`, and with `--no-color`.

#### The `progress` reporter

Shows how far the run has got, on standard error, while the mutants run. It follows StrykerJS's `progress` reporter, and its `progress-append-only` reporter where nobody watches. It counts the mutants that run tests. A mutant that has no run isn't in the count: one that no test reaches (`NoCoverage`), one that has no switch (`Ignored`), and one that isn't valid Ruby (`CompileError`). A run with no mutant to run shows nothing.

On a terminal, it draws one line at the start of the run and draws it again after each mutant, so the line changes in place, and it ends the line when the run ends:

```text
Mutation testing  [=========================                         ] 50% (elapsed: ~2m, remaining: ~2m) 5/10 Mutants tested (1 survived, 0 timed out)
```

Where standard error isn't a terminal, such as a CI log or a file, it draws no animation. It appends a line, without the bar, once ten seconds of the run have gone since the last line, and the first comes after ten seconds. A run of less than ten seconds writes none:

```text
Mutation testing 50% (elapsed: ~2m, remaining: ~2m) 5/10 tested (1 survived, 0 timed out)
```

The percent counts work, not mutants. The work of a mutant is the time that the tests which run against it took in the dry run, so a mutant that runs a slow test moves the percent further than one that runs a fast test. A mutant that runs in a fresh process, a static mutant, also adds the time that the dry run spent besides its tests. When no test took any time, each mutant counts the same. A mutant that times out counts as done.

The time is rough, in whole minutes rounded down: `<1m` below a minute, `~5m`, and `~1h 5m` from an hour on. The time left is the time so far, per unit of work done, times the work that is left. It is `n/a` before the first mutant is tested, when no work is left, and when the time left, in whole seconds, rounds down to less than one second, as in StrykerJS.

On a terminal, the bar is 50 characters wide, or as wide as the rest of the line leaves room for in the width that the terminal gives, and it has no width on a terminal too narrow for the rest of the line. The filled part of the bar is green, a count of survivors above zero is red, and a count of timeouts above zero is yellow. The reporter paints nothing when standard error isn't a terminal, when the environment sets `NO_COLOR`, when `TERM` is `dumb`, and with `--no-color`, and it still animates on a terminal in those cases.

A run that stops before it ends leaves the last line drawn, and the message that stops it follows on the same line.

#### The `json` reporter

Writes the run's report to `reports/mutation/mutation.json` in the project's root, once, when the run ends. It creates the folders, and replaces the report of an earlier run. A run that stops before it ends leaves the file as it was. When a file that has a mutant, or a test file, no longer exists at the end of the run, the reporter stops with that error and writes no report.

The report is one line of JSON in the [mutation testing report schema](https://github.com/stryker-mutator/mutation-testing-elements/tree/master/packages/report-schema) (schema version `1.0`) that the Stryker tools share, so any viewer of that schema reads it. `files` holds each file that has a mutant, by its path from the project's root, with its language, `ruby`, its source, and its mutants. `testFiles` holds each test file by its path, with its source and its tests: each test's `id`, `name`, and `location`. A test with no file goes under the empty name, with no source. A field with no value is left out of a mutant or a test.

| Field of a mutant | What it holds |
| - | - |
| `id` | The mutant's number in the run, as a string. |
| `mutatorName` | The name of the mutator that made the mutant. |
| `replacement` | The text that replaces the range in `location`. |
| `description` | What the mutant changed in a regular expression's pattern, as in `Anchor "^" was removed at offset 0.`. Only mutants of the `Regex` mutator have one. |
| `location` | The range in the file that the mutant replaces: `start` and `end`, each with a `line` and a `column` counted from 1. `end` is just after the range. Columns count UTF-16 code units, as JavaScript counts the index of a character in a string, so an emoji takes two columns. |
| `status` | `Killed`, `Survived`, `NoCoverage`, `CompileError`, `RuntimeError`, `Timeout`, or `Ignored`. |
| `statusReason` | Why the mutant has that status, for a status that has a reason. A mutant that no test can run with has the status `Ignored`, and the reason says why: its mutator is in `mutator.excludedMutations`, a disable comment covers it, its site can't hold a switch, or its text has no form on one line. |
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

The dry run runs alone, and the runs of static mutants run up to [`concurrency`](#concurrency) at once, each through every test, so they slow each other down. A static mutant's run that passes its limit runs again once every other static mutant's run has ended, with no other run beside it, and the mutant's status is that run's: `Survived`, `Killed`, or `Timeout` again. A static mutant that hangs takes its limit twice, and those second runs go one after another.

### `dryRunTimeoutMinutes`

How many minutes the dry run's tests may take, from the start of the first test to the end of the last. It takes any number of 0 or more, such as `0.5`. The default is `5`, as in StrykerJS. A dry run that takes longer fails the run, with an error that names this option. Raise it for a test suite that takes longer than 5 minutes to run once.

### `mutator.excludedMutations`

The names of the mutators to turn off, such as `"BooleanLiteral"`. The default is an empty list.

Each mutant of an excluded mutator is still made and reported. It has the status `Ignored` and the `statusReason` `Ignored because of excluded mutation "BooleanLiteral"`, gets no switch, and never runs. An `Ignored` mutant counts toward the total but toward no mutation score. An excluded mutator's mutants hold no other mutator's mutant back: with `StringLiteral` excluded, `notify("Saved")` still gets its removal.

A name matches a mutator's name exactly, with its letter case: `Equality` is the name of Stryker.NET's mutator, and the name here is `EqualityOperator`. A name that no mutator has is an error that lists the valid names. StrykerJS ignores such a name, so a misspelled name would leave its mutator running, and the run stops here instead. [Mutators](contributors/design/mutators.md#the-catalog) lists the names, and [Turning mutators off](contributors/design/mutators.md#turning-mutators-off) says what an excluded mutator's mutants report. To turn a mutator off at one site, use a [disable comment](#disable-comments).

### `incremental`

A boolean. The default is `false`.

### `minitest.testFiles`

The test files that the `minitest` test runner loads: a list of glob patterns, relative to the project's root. The default is `test/**/test_*.rb` and `test/**/*_test.rb`, the files that Minitest 6's `Minitest::TestTask` loads.

A value that you give replaces the default and never adds to it. A project that keeps tests in `plugins/*/test` as well lists the default patterns too:

```yaml
minitest:
  testFiles:
    - test/**/test_*.rb
    - test/**/*_test.rb
    - plugins/*/test/*_test.rb
```

The same value as a flag:

```sh
stryker run --minitest.test-files "test/**/test_*.rb,test/**/*_test.rb,plugins/*/test/*_test.rb"
```

A run with `testFiles` that leaves out a folder of tests has no test in that folder. A mutant that only those tests reach has the status `NoCoverage`, and the report doesn't say why.

The patterns follow the same rules as those of [`mutate`](#mutate), with these differences:

- A pattern that starts with `!` leaves nothing out. The `!` is an ordinary character in a file name, so the pattern matches only a file whose name starts with `!`.
- A pattern that matches a folder makes the project process fail to load it. The run stops with status 2, and the error says the project's tests failed to load. Write `plugins/*/test/*_test.rb`, not `plugins/**/*`.
- A pattern that matches no file loads nothing and is not an error, and neither is an empty list. A run with no test file finds no test, and every mutant has the status `NoCoverage`.
- A pattern that resolves outside the project's root, or that holds a NUL byte, is an error, as it is for `mutate`.
- A pattern whose bytes aren't valid UTF-8 is an error, because the test runner's options reach each project process as JSON, which holds only UTF-8. A `mutate` pattern with such bytes is accepted, because `mutate` stays in the command, which reads files whatever their names.

The test runner loads `test/test_helper.rb` first when the project has one, whatever `testFiles` holds. Then it loads each file that a pattern matches once, in the order of the files' paths, even when two patterns match the same file. Every project process loads these files, so a pattern that matches files that aren't tests loads them in each process.

## Disable comments

A disable comment turns mutators off for one line, or for the rest of a `.rb` file, and records why. Use one for a mutant that no test can kill, such as an equivalent mutant, and give the reason in the comment. It has the grammar of [StrykerJS's disable comments](https://stryker-mutator.io/docs/stryker-js/disable-mutants/), in Ruby's comment syntax:

```ruby
# Stryker [disable|restore] [next-line] <mutators>[: <reason>]
```

- `disable` turns the mutators off, and `restore` turns them back on.
- With `next-line`, the comment applies to the mutants whose code starts on the next line that holds code. A blank line, a comment, and a `=begin` block hold no code. Without `next-line`, the comment applies from its line to the end of the file, or until a `restore` for the same mutators.
- `<mutators>` is a comma-separated list of mutator names, or `all`. Names match without regard to letter case. For a name that no mutator has, the run writes a warning to standard error with the file and the line, and the rest of the comment still applies. [Mutators](contributors/design/mutators.md#the-catalog) lists the names.
- `<reason>`, after a colon, is the reason that the report gives.

Each mutant that a comment covers is made and reported with the status `Ignored`. Its `statusReason` is the reason in the comment, or `Ignored using a comment` when the comment has none. It gets no switch, no test runs against it, and it counts toward no mutation score. A comment covers a mutant by the line where the mutant's code starts, even when that code spans several lines. Of the comments that cover a mutant, the latest in the file applies, so a `restore` after a `disable` turns the mutant back on. When a comment and [`mutator.excludedMutations`](#mutatorexcludedmutations) both ignore a mutant, the report gives the comment's reason.

A comment lists mutators, not individual mutants, so it ignores every mutant of each mutator it names on its lines. Like an excluded mutator, a mutator that a comment turns off holds no other mutator's mutant back: a comment for `StringLiteral` leaves the removal of `notify("Saved")` live.

The comment's text after the `#` has to start with `Stryker`, with at most one whitespace character between the `#` and `Stryker`. A comment that follows code on its line counts, and without `next-line` it covers its line and the lines after it. Only a `#` comment counts, so `=begin` blocks, strings, heredocs, and the data after `__END__` hold none. A comment that doesn't match the grammar is an ordinary comment. [The disable comment](contributors/design/mutators.md#the-disable-comment) gives the exact pattern and the reasons for these rules.

### An equivalent mutant

A fee that starts after a free allowance has an equivalent mutant: at exactly `FREE_HOURS`, both branches give `0`, so `hours >= FREE_HOURS` behaves as `hours > FREE_HOURS` does. Mark it on the line before:

```ruby
# Stryker disable next-line EqualityOperator: at FREE_HOURS both branches give 0, so the >= mutant is equivalent
fee = (hours > FREE_HOURS) ? (hours - FREE_HOURS) * RATE : 0
```

Both of that line's `EqualityOperator` mutants are `Ignored` with that reason, the `<=` mutant as well, which isn't equivalent. The line's `ConditionalExpression` mutants still run.

### A condition that is always true under the tests

A condition that is always true while the tests run, such as `Rails.env.test?`, has a `ConditionalExpression` mutant that no test can kill. Mark it on the line before:

```ruby
# Stryker disable next-line ConditionalExpression: Rails.env.test? is always true under the tests
deliver_later unless Rails.env.test?
```

### Part of a file

Use `all` with `disable`, and end the part with `restore`:

```ruby
# Stryker disable all: generated from the carrier's rate table
RATES = {
  # The generated rates go here.
}.freeze
# Stryker restore all
```

### Comments that turn nothing off

A comment with an unknown mutator name turns nothing off, and a comment that doesn't match the grammar is an ordinary comment:

```ruby
# Wrong: "next line" has a space where the grammar needs a hyphen. The comment matches
# the grammar, and its whole list, "next line EqualityOperator", is one unknown name,
# so the run writes a warning and the mutants on the next line stay live.
# Stryker disable next line EqualityOperator
total -= total * @rate if order.quantity > BULK_THRESHOLD
```

```ruby
# Wrong: "@stryker" isn't "Stryker", so this is an ordinary comment.
# @stryker disable next-line all
total -= total * @rate if order.quantity > BULK_THRESHOLD
```

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
