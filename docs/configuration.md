# Configuration

This page lists every option of **Stryker (for Ruby)**: its name, its type, its default, and what it is for. A run isn't built yet: `stryker run` reads the configuration, checks it, and stops with status 2. This page describes what the command does now, and says what a run will use an option for only where you need that to fill the option in. The options and their defaults are those of [StrykerJS](https://stryker-mutator.io/docs/stryker-js/configuration/), except `mutate` and `testRunner`, whose defaults are for Ruby, and the options that mean nothing in Ruby, which are left out.

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
| `stryker run [configFile]` | Checks the configuration, then stops with status 2. |
| `stryker help [command]` | Writes the overview of the commands, or the help of one command, to standard output. |
| `stryker -h`, `stryker --help` | The same as `stryker help`. After `run`, `-h` or `--help` writes the help of `stryker run` and does nothing else. |
| `stryker --version` | Writes the version to standard output. |
| `stryker` with no words | Writes the overview to standard error, and exits with status 2. |

There is no `-v`, because other tools use it for both "verbose" and "version". A command that doesn't exist is an error that suggests the nearest command and exits with status 2:

```text
Unknown command "hlep". Did you mean "help"? Run "stryker help" for the commands.
```

A run isn't built yet. `stryker run` reads the file and the flags and runs every check, and with no problem it writes `A run isn't built yet: the command reads and checks the configuration, and then stops.` to standard error and exits with status 2.

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
| 0 | `stryker help`, `stryker -h`, `stryker --help`, `stryker --version`, and `stryker run -h` wrote their text. |
| 2 | The command couldn't do what you asked: a command line, flag, or configuration error, or an error in **Stryker (for Ruby)** itself. An error in **Stryker (for Ruby)** writes its backtrace and the address to report it at. `stryker run` also exits with 2 when its checks find no problem, because a run isn't built. |
| 128 plus the signal's number | A signal ended `stryker run`: 130 for Ctrl-C (`INT`) and 143 for `TERM`. The command writes `Stopped by INT.` or `Stopped by TERM.` to standard error. |

The command gives no status 1 today. `stryker help run` lists it for a score below `thresholds.break`, which only a run has.

#### Output

Help and the version go to standard output. Errors go to standard error, and so does the overview that `stryker` writes when it has no words.

Nothing that the command writes has color. `stryker run` accepts `--no-color`, and the flag changes nothing today.

## Checks

Before it does anything else, `stryker run` checks every option in the file and on the command line, including a file option that a flag replaces. The message has one line for each problem, and each line says which file or flag the value came from. The command exits with status 2.

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

The checks read the type of `testRunner` and `reporters`. They don't check that a test runner or a reporter with that name exists.

## Options

Each entry says what the option is for. Where an option's effect is on a run, the entry says what a run will use it for, so that you can fill it in. `stryker run` reads and checks every option, and nothing else uses one today.

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

An empty list selects no file.

### `testRunner`

The name of the test runner for the project's tests, such as `minitest` or `rspec`.

With no value, the project's folders choose it: `minitest` when the project has a `test/` folder, and `rspec` when it has a `spec/` folder. A project with neither, or with both, is an error that asks you to set `testRunner` in the configuration file or pass `--test-runner`. A file called `test` isn't a `test/` folder.

### `reporters`

A list of reporter names. The default is `clear-text`, `progress`, and `html`. For `clear-text`, a run will write a summary of its results to standard output. For `json`, it will write the report to `reports/mutation/mutation.json` in the project's root, in the [mutation testing report schema](https://github.com/stryker-mutator/mutation-testing-elements/tree/master/packages/report-schema) that the Stryker tools share.

### `concurrency`

The number of project processes that a run will start at once. It takes a whole number of 1 or more, or a percentage string from `"0%"` to `"100%"` that is a share of the logical processors. A percentage rounds half up, as StrykerJS rounds it, and never gives fewer than 1. On a machine with 8 processors, `"50%"` is 4, `"100%"` is 8, and `"1%"` is 1.

With no value, a machine with 1 to 4 processors uses that many, and a machine with more uses one fewer: 7 on a machine with 8.

A whole number may be more than the number of processors.

### `thresholds.high`

The mutation score, as a percentage, at or above which a report will count the score as high. It takes a whole number from 0 to 100, such as `80`. `80.0` counts as a whole number, and the configuration holds it as `80`. A fraction such as `82.5` is an error, because the JSON report holds this threshold as an integer and a report with a fraction would fail its schema. The default is `80`. A report will use it to color the score. It can't be below `thresholds.low`.

### `thresholds.low`

The mutation score, as a percentage, below which a report will count the score as low. It takes a whole number from 0 to 100, such as `60`. A fraction is an error, for the reason that `thresholds.high` gives. The default is `60`. A report will use it to color the score. It can't be above `thresholds.high`.

### `thresholds.break`

The mutation score, as a percentage, below which a run will exit with status 1. It takes any number from 0 to 100, such as `80.5`, or null. Unlike `thresholds.high` and `thresholds.low`, it may be a fraction, because it never reaches the report. The default is null, which sets no limit. `0` is a limit that no score is below.

### `timeoutMS`

The milliseconds that a run will add to the dry-run time of a mutant's tests, to make the mutant's time limit. It takes any number of 0 or more, such as `2500.5`. The default is `5000`.

### `timeoutFactor`

How many times the dry-run time of a mutant's tests the mutant's run may take, before `timeoutMS` is added. It takes any number of 0 or more. The default is `1.5`.

The limit of a mutant's run will be the dry-run time of its tests, times `timeoutFactor`, plus `timeoutMS`, plus the dry run's overhead, rounded up to a whole millisecond, as in StrykerJS. The overhead is the test runner's time between tests in the dry run.

```text
limit = dry-run time of the mutant's tests × timeoutFactor + timeoutMS + overhead
```

### `dryRunTimeoutMinutes`

How many minutes the dry run's tests may take, from the start of the first test to the end of the last. It takes any number of 0 or more, such as `0.5`. The default is `5`, as in StrykerJS.

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
