# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `stryker run` runs mutation testing on Linux and macOS, for a project that tests with Minitest. It mutates the Ruby files that `mutate` selects, runs every test once, runs the tests against each mutant in a process of its own, and reports with `clear-text` on standard output and `json` in `reports/mutation/mutation.json`. The `clear-text` report starts with the tree of the tests that the dry run found, each with the number of mutants it killed, or the number it reached when it killed none. It exits with status 1 when the mutation score is below `thresholds.break`. The report has color on a terminal, and none with `--no-color`, `NO_COLOR`, or `TERM=dumb`.
- A static mutant's run that passes its time limit runs again, alone, once every other static mutant's run has ended, and the mutant gets the status of that run. Static runs each run every test, up to `concurrency` at once, and slow each other down, so without the second run a mutant that survives alone could count as `Timeout`, which is detected. A static mutant that hangs takes its time limit twice.
- `stryker run` stops before it reads a file to mutate, with an error that says why, when `testRunner` isn't `minitest`, when `reporters` in the file or on the command line names a reporter other than `clear-text`, `progress`, and `json`, or when `mutate` in the file or on the command line selects an ERB template. The default `reporters` holds `html` too, which isn't built: a run with the default leaves it out, runs `clear-text` and `progress`, and writes a warning to standard error. The default `mutate` selects ERB templates too: a run with the default leaves them out, and writes a warning to standard error that says how many.
- `stryker run` stops with status 2 and an error that gives the path and the line of the first error, when a file that `mutate` selects isn't valid Ruby, and it writes no bug report.
- `stryker run` stops with status 2 and a plain message, and writes no bug report, when the project's test helper or test files raise while they load, such as a failing `Bundler.require`. The message says that the tests failed to load, gives the class and message of what they raised, and gives the last lines of the standard error of the process that loaded them.
- The default `progress` reporter shows how many mutants have been tested, how many of them survived or timed out, and the time left, on standard error while `stryker run` goes. On a terminal it draws one line and draws it again after each mutant, with a bar that fills as the run goes. Elsewhere it appends a line every ten seconds. It has color on a terminal, and none with `--no-color`, `NO_COLOR`, or `TERM=dumb`.
- The JSON report lists a mutant that no test can run with, with the status `Ignored` and a `statusReason` that says why. That covers a mutant of a mutator that `mutator.excludedMutations` lists, with the reason `Ignored because of excluded mutation "StringLiteral"`, a mutant that a disable comment covers, a mutant whose site can't hold a switch, as inside `BEGIN { }`, and one whose text has no form on one line. An `Ignored` mutant is in no mutation score, and it never removes another mutant that gives the same code.
- A comment in a `.rb` file turns mutators off for one line or for the rest of the file, with StrykerJS's grammar: `# Stryker disable next-line EqualityOperator: why`, `# Stryker disable all`, and `# Stryker restore all`. Each mutant that a comment covers has the status `Ignored`, and its `statusReason` is the reason after the colon, or `Ignored using a comment`. A mutator name that no mutator has writes a warning with the file and the line to standard error, and the rest of the comment still applies.
- The `Regex` mutator changes the pattern of a regexp literal and of the string given as the first argument of `Regexp.new`. It removes an anchor, turns `^` and `$` into `\A` and `\z`, negates a character class, a shorthand class such as `\d`, a Unicode property, and a lookaround, and removes a quantifier. Each mutant has a `description` in the JSON report, such as `Anchor "^" was removed at offset 0.`. A pattern with interpolation gets no mutant, and neither does a pattern that **Stryker (for Ruby)** can't read, which writes a warning with the file and the line to standard error. `mutator.excludedMutations` accepts `Regex`.
- The option `minitest.testFiles`, a list of globs relative to the project's root, chooses the test files that the `minitest` test runner loads, with the flag `--minitest.test-files`. It defaults to `test/**/test_*.rb` and `test/**/*_test.rb`, and a value replaces the default. A project that keeps tests outside `test/`, such as in `plugins/*/test`, no longer has `NoCoverage` for the mutants that those tests kill.

### Changed

- `stryker --version` and `stryker help` start about three times as fast, because they no longer load the parser that only `stryker run` uses.
- **Stryker (for Ruby)** prints the address of [the forum](https://forum.setdef.com/c/stryker-for-ruby) for reports, in place of GitHub Issues, in `stryker help` and in the message after an error in its code. The error message lists what to include in a report: the command you ran, what it printed, your Ruby version, your operating system, and the backtrace. The gem's `bug_tracker_uri` is the forum's address too.
- On Windows, `stryker run` stops after its checks with an error that says a run on Windows isn't built yet.

### Fixed

- `stryker run` refuses a flag value whose bytes aren't valid UTF-8, as a shell in a UTF-8 locale can pass, with an error that gives the flag and the exit status 2, where it printed a stack trace. `stryker run` keeps such a `--mutate` pattern, because a file's name can hold any bytes.
- `stryker` and `stryker help` refuse a command word or help topic whose bytes aren't valid UTF-8 with the line of an unknown command, which shows the bytes as escapes, and the exit status 2, where they printed a stack trace.

## [0.2.0] - 2026-11-28

### Changed

- `thresholds.high` and `thresholds.low` take only whole numbers from 0 to 100, as the JSON report's schema requires. A fraction such as `82.5` is now an error that says so, where the configuration took it and the report then failed its schema. `thresholds.break` still takes any number from 0 to 100.

### Fixed

- A JSON configuration file that holds bytes that aren't valid UTF-8 is now an error that names the file and the line, where it used to load with the bytes as they were.

## [0.1.0] - 2026-11-27

### Added

- `Stryker::VERSION`, the version of the gem.
- The `stryker` command, with `stryker run [configFile]`, `stryker help [command]`, `-h`, `--help`, and `--version`, a flag for every option, and the exit statuses 0, 1, 2, and 128 plus the signal's number. `stryker run` checks the configuration and then stops with status 2, because a run isn't built yet.

[Unreleased]: https://github.com/setdef/stryker_for_ruby/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/setdef/stryker_for_ruby/releases/tag/v0.2.0
[0.1.0]: https://github.com/setdef/stryker_for_ruby/releases/tag/v0.1.0
