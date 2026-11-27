# Stryker (for Ruby)

Mutation testing for Ruby projects that test with Minitest.

> [!NOTE]
> **Stryker (for Ruby)** is a community port of [Stryker Mutator](https://stryker-mutator.io), with no affiliation to that project. The maintainers hope to make it an official project of the [Stryker Mutator organization](https://github.com/stryker-mutator).

## What mutation testing is for

A coverage report shows which lines your tests ran, but not whether a test would fail if one of those lines were wrong. Mutation testing checks that. **Stryker (for Ruby)** makes one change to your code at a time, the kind of mistake a programmer makes, such as `>` in place of `>=`. Each changed version of the code is a mutant, and **Stryker (for Ruby)** runs your tests against each one. When a test fails, the mutant is killed. When every test passes, the mutant survived, and your tests would have missed that bug.

Each surviving mutant shows you something to do: write a test, make a test stricter, or remove code that nothing needs. The [mutation score](https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/) is the percentage of mutants that your tests killed.

**Stryker (for Ruby)** uses the mutator names, mutant statuses, scores, and [JSON report format](https://github.com/stryker-mutator/mutation-testing-elements/tree/master/packages/report-schema) of the other Stryker tools: [StrykerJS](https://github.com/stryker-mutator/stryker-js) for JavaScript and TypeScript, [Stryker.NET](https://github.com/stryker-mutator/stryker-net) for C#, and [Stryker4s](https://github.com/stryker-mutator/stryker4s) for Scala. Its options have the names of StrykerJS's options, and StrykerJS's defaults apart from `mutate` and `testRunner`. [mutant](https://github.com/mbj/mutant) is another mutation testing tool for Ruby.

## A first run

The project in this example has one file to mutate and two tests, written with Minitest's spec syntax.

<!-- SPDX-SnippetBegin -->
<!-- SPDX-License-Identifier: MIT-0 -->
<!-- SPDX-SnippetCopyrightText: 2026 setdef -->
```ruby
# lib/discount.rb
module Discount
  # The discount on an order, in percent: 10 from a total of 100.
  def self.rate(total)
    (total >= 100) ? 10 : 0
  end
end
```

```ruby
# test/test_helper.rb
require "discount"
require "minitest/autorun"
```

```ruby
# test/discount_test.rb
require "test_helper"

describe Discount do
  it "gives a large order ten percent" do
    _(Discount.rate(150)).must_equal(10)
  end

  it "gives a small order none" do
    _(Discount.rate(50)).must_equal(0)
  end
end
```
<!-- SPDX-SnippetEnd -->

With the gem [installed](#installation), in the project's root folder and with no configuration file, run:

```sh
stryker run
```

It prints:

```text
Warning: this run leaves out the default reporter "html", because Stryker (for Ruby) hasn't built it yet. Name the reporters you want, as in --reporters clear-text,json, to choose your own.

All tests/discount_test.rb
  ✓ test_0001_gives a large order ten percent (killed 4)
  ✓ test_0002_gives a small order none (killed 2)

[Survived] EqualityOperator
lib/discount.rb:4:6
-       (total >= 100) ? 10 : 0
+       (total > 100) ? 10 : 0
Tests ran:
    test_0001_gives a large order ten percent
    test_0002_gives a small order none


Ran 1.29 tests per mutant on average.
-------------|------------------|----------|-----------|------------|----------|----------|
             | % Mutation score |          |           |            |          |          |
File         |  total | covered | # killed | # timeout | # survived | # no cov | # errors |
-------------|--------|---------|----------|-----------|------------|----------|----------|
All files    |  85.71 |   85.71 |        6 |         0 |          1 |        0 |        0 |
 discount.rb |  85.71 |   85.71 |        6 |         0 |          1 |        0 |        0 |
-------------|--------|---------|----------|-----------|------------|----------|----------|
```

The tests killed six of the seven mutants. The one that survived turns `>=` into `>`, and no test checks a total of exactly 100. A test that expects `Discount.rate(100)` to be `10` would kill it.

The warning goes to standard error, and the report to standard output. On a terminal, the report has color, and the `progress` reporter draws a bar on standard error that fills as the mutants run.

## Compatibility

| | Status |
| - | - |
| Ruby 4.0 and later | Supported. |
| Ruby 3.3 and 3.4 | Unsupported. You can install and run the gem on them, at your own risk. [Ruby 3.3 and 3.4](docs/older-ruby.md) lists the problems found on them. |
| Ruby 3.2 and older | RubyGems refuses to install the gem. |
| Linux and macOS | `stryker run` runs mutation testing. |
| Windows | `stryker run` checks the configuration, then stops with status 2, because a run on Windows isn't built yet. |
| Minitest 6 | The one test runner, `minitest`. Your tests live in `test/`, in files named `test_*.rb` or `*_test.rb`, and **Stryker (for Ruby)** loads `test/test_helper.rb` first, if you have one. |
| RSpec | Not available. A project with a `spec/` folder and no `test/` folder gets an error that says so. |
| ERB templates | Not mutated. A run with the default `mutate` patterns leaves them out, with a warning that says how many. |

## Installation

**Stryker (for Ruby)** is published only as [GitHub releases](https://github.com/setdef/stryker_for_ruby/releases), not on RubyGems.org. Each release holds the gem file and a `SHA256SUMS` file with its checksum. These commands download the latest release's gem, check it against the checksum, and install it with its dependencies:

<!-- SPDX-SnippetBegin -->
<!-- SPDX-License-Identifier: MIT-0 -->
<!-- SPDX-SnippetCopyrightText: 2026 setdef -->
```sh
curl -fsSLO https://github.com/setdef/stryker_for_ruby/releases/latest/download/SHA256SUMS
gem_file=$(awk '{ print $2 }' SHA256SUMS)
curl -fsSLO "https://github.com/setdef/stryker_for_ruby/releases/latest/download/$gem_file"
sha256sum -c SHA256SUMS
gem install "./$gem_file"
```
<!-- SPDX-SnippetEnd -->

Where `sha256sum` is missing, `shasum -a 256 -c SHA256SUMS` does the same check. For another release, replace `latest/download` with `download/` and the release's tag. `stryker --version` prints the version you installed.

This README describes the code on `trunk`. The [changelog](CHANGELOG.md) lists what each release holds, and its Unreleased section lists what is on `trunk` and in no release yet.

## Usage

Run `stryker run` in your project's root folder. It reads the configuration, finds the files to mutate, runs your tests once with no mutant, and then runs them against each mutant, each run in a separate process, several at once. Your source files stay as they are: the mutated code goes to a temporary folder. `stryker help run` lists every flag.

### The configuration file

A configuration file is optional. Without one, `stryker run` uses the defaults and its flags. **Stryker (for Ruby)** looks in the project's root folder for `stryker.config.json`, then `stryker.config.yml`, and stops with an error when it finds both. `stryker run path/to/file.yml` reads that file instead.

The file holds one object whose keys are option names. For example, with this `stryker.config.json`, `stryker run` mutates only the files in `lib`, runs all three built reporters, and exits with status 1 when the mutation score is below 80:

<!-- SPDX-SnippetBegin -->
<!-- SPDX-License-Identifier: MIT-0 -->
<!-- SPDX-SnippetCopyrightText: 2026 setdef -->
```json
{
  "mutate": ["lib/**/*.rb"],
  "reporters": ["clear-text", "progress", "json"],
  "thresholds": { "break": 80 }
}
```
<!-- SPDX-SnippetEnd -->

Every option is also a flag, in kebab case, and `stryker run` takes a flag's value over the file's: `stryker run --thresholds.break 90`.

The options you are most likely to set:

- `mutate`: glob patterns for the files to mutate. The default is the Ruby files in `lib` and `app`, leaving out test files.
- `reporters`: `clear-text` writes the summary in the first-run example to standard output, `progress` shows how far the run has got, on standard error, and `json` writes `reports/mutation/mutation.json` in the [mutation testing report schema](https://github.com/stryker-mutator/mutation-testing-elements/tree/master/packages/report-schema). The default list also holds `html`, which isn't built, so a run with the default leaves it out with the warning in the first-run example.
- `thresholds.break`: the score below which the run exits with status 1.
- `concurrency`: how many processes run tests at once.
- `mutator.excludedMutations`: the names of mutators to turn off.

[Configuration](docs/configuration.md) lists every option with its type and default, the flags, the checks `stryker run` makes before it starts, and what each reporter writes.

### Disable comments

With a disable comment in a `.rb` file, you turn mutators off for the next line, or for the rest of the file until a restore comment:

<!-- SPDX-SnippetBegin -->
<!-- SPDX-License-Identifier: MIT-0 -->
<!-- SPDX-SnippetCopyrightText: 2026 setdef -->
```ruby
# Stryker disable next-line EqualityOperator: the checkout's end-to-end tests check the boundary at 100
(total >= 100) ? 10 : 0
```
<!-- SPDX-SnippetEnd -->

The mutants that the comment covers have the status `Ignored`, count toward no score, and keep the reason in the JSON report. [Disable comments](docs/configuration.md#disable-comments) gives the grammar and more examples, and [the catalog](docs/contributors/design/mutators.md#the-catalog) lists every mutator and what it changes.

### Exit statuses

| Status | When |
| - | - |
| 0 | The run finished with a score at or above `thresholds.break`, or with no break set. |
| 1 | The run finished with a score below `thresholds.break`. |
| 2 | The run couldn't finish: an error in the command line or the configuration, a file to mutate that isn't valid Ruby, tests that failed to load, a test that failed with no mutant active, a run on Windows, or an error in **Stryker (for Ruby)** itself. |
| 128 plus the signal's number | A signal stopped the run: 130 for Ctrl-C, 143 for `TERM`. |

[Exit statuses](docs/configuration.md#exit-statuses) describes each case in full.

## Documentation

- [Configuration](docs/configuration.md): every option, flag, check, reporter, and exit status, and the disable comment.
- [Ruby 3.3 and 3.4](docs/older-ruby.md): the problems found on the unsupported Rubies.
- [Changelog](CHANGELOG.md): what changed in each release, and what is on `trunk` and in no release yet.
- [Contributor documentation](docs/contributors/README.md): how the code works inside and why, for the people who change it.

## Reporting problems

Open an issue in [the issue tracker](https://github.com/setdef/stryker_for_ruby/issues). Include the command you ran, what it printed, your Ruby version, and your operating system. When **Stryker (for Ruby)** stops because of an error in its code, it prints a backtrace and the address to report it at: include the backtrace.

Report a security problem privately, as [SECURITY.md](SECURITY.md) says, never in the issue tracker.

## Contributing

[Working on Stryker (for Ruby)](CONTRIBUTING.md) holds the rules for every change, and [the contributor documentation](docs/contributors/README.md) explains the design.

## License

**Stryker (for Ruby)** is copyright 2026, setdef, and licensed under the Apache License 2.0; see [LICENSES/Apache-2.0.txt](LICENSES/Apache-2.0.txt) for the full text.

Some parts are copied from other projects under those projects' licenses, and their authors keep the copyright in them. The project follows the [REUSE Specification](https://reuse.software/spec-3.3/): `REUSE.toml` and the comments in each such file list its license and copyright. The code examples in this README are under the MIT No Attribution license; see [LICENSES/MIT-0.txt](LICENSES/MIT-0.txt).

## How this was made

I use three words for how code and prose comes to exist. Code or prose I wrote, I typed by hand, with nothing generated. Code or prose I wrought, an AI agent generated while I iterated with it, and I reviewed every change before committing it, so I take responsibility for every diff. Code or prose I requested, an agent built with little or no review from me, in the style of a "dark factory."

The code, tests, and documentation of **Stryker (for Ruby)**, this README included, were requested. Agents built them from my goals and decisions, with little review of the diffs. In place of review, the project's rules require test-driven development with each new test seen to fail first, 100% test coverage of every file, RubyCritic, RuboCop, Steep, documentation coverage, and `reuse lint` with no errors or warnings, a run of the tests on Ruby 4.0 before each push, and the full build on Linux, macOS, and Windows after it. [declare-ai.org](https://declare-ai.org/1.0.0/total.html).
