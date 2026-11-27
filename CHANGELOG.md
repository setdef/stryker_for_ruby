# Changelog

Every change that people who use **Stryker (for Ruby)** will see is listed here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Releases are numbered with [Semantic Versioning](https://semver.org/), as `0.X.Y` until 1.0.0. Each is a GitHub release, and nothing is published outside GitHub before 1.0.0. A release's section is dated and filled in after its tag, so [Unreleased] lists every change that no release holds yet.

## [Unreleased]

### Added

- `stryker run` runs mutation testing on Linux and macOS, for a project that tests with Minitest. It mutates the Ruby files that `mutate` selects, runs every test once, runs the tests against each mutant in a process of its own, and reports with `clear-text` on standard output and `json` in `reports/mutation/mutation.json`. It exits with status 1 when the mutation score is below `thresholds.break`. The report has color on a terminal, and none with `--no-color`, `NO_COLOR`, or `TERM=dumb`.
- `stryker run` stops before it reads a file to mutate, with an error that says why, when `testRunner` isn't `minitest`, when `reporters` in the file or on the command line names a reporter other than `clear-text` and `json`, or when `mutate` in the file or on the command line selects an ERB template. The default `reporters` holds `progress` and `html` too, which aren't built: a run with the default leaves them out, runs `clear-text`, and writes a warning to standard error. The default `mutate` selects ERB templates too: a run with the default leaves them out, and writes a warning to standard error that says how many.
- `stryker run` stops with status 2 and an error that gives the path and the line of the first error, when a file that `mutate` selects isn't valid Ruby, and it writes no bug report.

### Changed

- `stryker --version` and `stryker help` start about three times as fast, because they no longer load the parser that only `stryker run` uses.
- On Windows, `stryker run` stops after its checks with an error that says a run on Windows isn't built yet.
- `thresholds.high` and `thresholds.low` take only whole numbers from 0 to 100, as the JSON report's schema requires. A fraction such as `82.5` is now an error that says so, where the configuration took it and the report then failed its schema. `thresholds.break` still takes any number from 0 to 100.

### Fixed

- A JSON configuration file that holds bytes that aren't valid UTF-8 is now an error that names the file and the line, where it used to load with the bytes as they were.

## [0.1.0] - 2026-11-27

### Added

- `Stryker::VERSION`, the version of the gem.
- The `stryker` command, with `stryker run [configFile]`, `stryker help [command]`, `-h`, `--help`, and `--version`, a flag for every option, and the exit statuses 0, 1, 2, and 128 plus the signal's number. `stryker run` checks the configuration and then stops with status 2, because a run isn't built yet.
