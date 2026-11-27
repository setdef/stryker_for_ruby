# Changelog

Every change that people who use **Stryker (for Ruby)** will see is listed here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Releases are numbered with [Semantic Versioning](https://semver.org/), as `0.X.Y` until 1.0.0. Each is a GitHub release, and nothing is published outside GitHub before 1.0.0. A release's section is dated and filled in after its tag, so [Unreleased] lists every change that no release holds yet.

## [Unreleased]

### Changed

- `thresholds.high` and `thresholds.low` take only whole numbers from 0 to 100, as the JSON report's schema requires. A fraction such as `82.5` is now an error that says so, where the configuration took it and the report then failed its schema. `thresholds.break` still takes any number from 0 to 100.

### Fixed

- A JSON configuration file that holds bytes that aren't valid UTF-8 is now an error that names the file and the line, where it used to load with the bytes as they were.

## [0.1.0] - 2026-11-27

### Added

- `Stryker::VERSION`, the version of the gem.
- The `stryker` command, with `stryker run [configFile]`, `stryker help [command]`, `-h`, `--help`, and `--version`, a flag for every option, and the exit statuses 0, 1, 2, and 128 plus the signal's number. `stryker run` checks the configuration and then stops with status 2, because a run isn't built yet.
