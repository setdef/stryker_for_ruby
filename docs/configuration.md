# Configuration

This page lists every option of **Stryker (for Ruby)**: its name, its type, its default, and what it does. The options and their defaults are those of [StrykerJS](https://stryker-mutator.io/docs/stryker-js/configuration/), except `mutate` and `testRunner`, whose defaults are for Ruby, and the options that mean nothing in Ruby, which are left out.

## Where options come from

An option takes its value from the first of these that gives one:

1. The command line.
2. The configuration file.
3. The default.

A value on the command line replaces the file's value for that option. A list, such as `mutate`, is replaced as a whole, never added to.

### The configuration file

A configuration file is JSON or YAML, and holds one object whose keys are option names. Nested options have a parent key: `thresholds` holds `high`, `low`, and `break`, and `mutator` holds `excludedMutations`. This page writes a nested option with a dot, as `thresholds.break`. In a file, either spelling works: a `thresholds` object with a `break` key, or the key `"thresholds.break"`.

**Stryker (for Ruby)** looks for these files in the project's root, in this order:

1. `stryker.config.json`
2. `stryker.config.yml`

With neither file, a run uses the defaults and the command line. With both, the run stops, because it can't tell which one you mean: delete one, or name the one to read, as in `stryker run stryker.config.yml`. A file you name takes the place of both. A named file whose name doesn't end in `.json`, `.yml`, or `.yaml` is an error, and so is one that doesn't exist.

An empty YAML file has no options. A YAML file may hold only strings, numbers, booleans, null, lists, and maps. A date, a symbol, an alias, or a tag that names a Ruby class is an error, because the file comes from the project and loading it must never run code.

### The command line

Every option is also a flag. The flag is the kebab-case form of the option's name, with its dots kept: `testRunner` is `--test-runner`, `timeoutMS` is `--timeout-ms`, and `mutator.excludedMutations` is `--mutator.excluded-mutations`. `-m` is short for `--mutate` and `-c` for `--concurrency`.

## Checks

Before it does anything else, **Stryker (for Ruby)** checks every option in the file and on the command line, including a file option that a flag replaces. A run with a problem stops before it parses any file. The message has one line for each problem, and each line says which file or flag the value came from. The run exits with status 2.

- **An option that doesn't exist** is an error that suggests the nearest name:

  ```text
  Unknown option "timeoutMs" in stryker.config.json. Did you mean "timeoutMS"?
  ```

- **A value of the wrong type** is an error that gives the option, the type it takes, and the value:

  ```text
  "concurrency" in stryker.config.json takes a whole number of 1 or more, or a percentage of the processors such as "50%", but its value is 0.
  ```

- **A `thresholds.high` below `thresholds.low`** is an error that names both options and where each value came from. An option that no file or flag sets counts with its default, so `thresholds.high` of `50` alone is below the default `thresholds.low` of `60`. Equal values are fine ([`thresholds.high`](#thresholdshigh)).
- **A name in `mutator.excludedMutations` that no mutator has** is an error that lists the valid names ([`mutator.excludedMutations`](#mutatorexcludedmutations)).
- **A pattern in `mutate` that resolves outside the project's root** is an error ([`mutate`](#mutate)).
- **A pattern in `mutate` with a NUL byte** is an error, because no file name holds one. In JSON, a NUL byte is the escape `\u0000`.

The checks read the type of `testRunner` and `reporters`. They don't check that a test runner or a reporter with that name exists.

## Options

| Option | Type | Default |
| - | - | - |
| [`mutate`](#mutate) | list of strings | `lib/**/*.rb` and `app/**/*.rb`, with `.erb` too, leaving out test files |
| [`testRunner`](#testrunner) | string | `minitest` when the project has a `test/` folder, `rspec` when it has a `spec/` folder |
| [`reporters`](#reporters) | list of strings | `clear-text`, `progress`, `html` |
| [`concurrency`](#concurrency) | whole number, or a percentage string | the number of logical processors, less one when there are more than four |
| [`thresholds.high`](#thresholdshigh) | whole number from 0 to 100 | `80` |
| [`thresholds.low`](#thresholdslow) | whole number from 0 to 100 | `60` |
| [`thresholds.break`](#thresholdsbreak) | whole number from 0 to 100, or null | none |
| [`timeoutMS`](#timeoutms) | whole number of 0 or more | `5000` |
| [`timeoutFactor`](#timeoutfactor) | number of 0 or more | `1.5` |
| [`mutator.excludedMutations`](#mutatorexcludedmutations) | list of strings | none |
| [`incremental`](#incremental) | boolean | `false` |

### `mutate`

The files to mutate: a list of glob patterns, relative to the project's root. A pattern that starts with `!` leaves files out, as in `"!lib/generated/**/*.rb"`.

The default is `lib/**/*.rb`, `app/**/*.rb`, `lib/**/*.erb`, and `app/**/*.erb`, with the files below left out:

- the files in any `test/` or `spec/` folder, at any depth;
- the files whose names end in `_test.rb` or `_spec.rb`.

A mutant in a test file changes the test that judges it, so the default leaves test files out. A pattern that you write replaces the default and can match a test file. Nothing stops it, and that file then gets mutants.

A pattern that resolves outside the project's root is an error, such as `../shared/lib/**/*.rb`, or an absolute path to a folder that isn't inside the root. A pattern that goes up and comes back, such as `lib/../app/**/*.rb`, resolves inside the root and is fine. The check reads the text of the pattern, so it doesn't expand `{a,b}` alternatives. A `~` is an ordinary character, as it is in a glob, so `~/lib/**/*.rb` is a folder named `~` inside the root.

An empty list selects no file.

### `testRunner`

The test runner that runs the project's tests: `minitest` or `rspec`.

With no value, the project's folders choose it: `minitest` when the project has a `test/` folder, and `rspec` when it has a `spec/` folder. A project with neither, or with both, is an error that asks you to set `testRunner` in the configuration file or pass `--test-runner`. A file called `test` isn't a `test/` folder.

### `reporters`

A list of reporter names. The default is `clear-text`, `progress`, and `html`.

### `concurrency`

How many project processes run at once. It takes a whole number of 1 or more, or a percentage string from `"0%"` to `"100%"` that is a share of the logical processors. A percentage rounds half up, as StrykerJS rounds it, and never gives fewer than 1. On a machine with 8 processors, `"50%"` is 4, `"100%"` is 8, and `"1%"` is 1.

With no value, a machine with 1 to 4 processors uses that many, and a machine with more uses one fewer: 7 on a machine with 8.

A whole number may be more than the number of processors. Each project process loads your code, so more processes use more memory.

### `thresholds.high`

The mutation score, as a percentage, at or above which the score counts as high. The default is `80`. Reports use it to color the score. It can't be below `thresholds.low`.

### `thresholds.low`

The mutation score, as a percentage, below which the score counts as low. The default is `60`. Reports use it to color the score. It can't be above `thresholds.high`.

### `thresholds.break`

The mutation score, as a percentage, below which the run exits with status 1. The default is null, which sets no limit. `0` is a limit that no score is below. Set it in CI to fail a build when the tests get weaker: `stryker run --thresholds.break 75`.

### `timeoutMS`

The milliseconds that a run's time limit adds to the dry-run time of its tests. The default is `5000`. Raise it on a busy machine, so that a slow run isn't taken for an infinite loop.

### `timeoutFactor`

How many times the dry-run time of a run's tests a run may take, before `timeoutMS` is added. The default is `1.5`. Raise it when mutants make the code slower without making it loop forever. Use `timeoutMS` for a mutant that loops forever.

A run's limit is the dry-run time of the tests that reach the mutant, times `timeoutFactor`, plus `timeoutMS`.

### `mutator.excludedMutations`

The names of the mutators that make no mutant, such as `"BooleanLiteral"`. The default is an empty list.

A name matches a mutator's name exactly, with its letter case: `Equality` is the name of Stryker.NET's mutator, and the name here is `EqualityOperator`. A name that no mutator has is an error that lists the valid names. StrykerJS ignores such a name, so a misspelled name would leave its mutator running, and the run stops here instead. [Mutators](design/mutators.md#the-catalog) lists the names.

### `incremental`

A boolean. The default is `false`.

## Example files

The same configuration in each format. It mutates only the models and the services, runs RSpec with half of the processors, fails a run whose score is below 75, and turns off two mutators:

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
