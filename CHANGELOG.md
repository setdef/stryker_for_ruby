# Changelog

Every change that people who use **Stryker (for Ruby)** will see is listed here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Releases are numbered with [Semantic Versioning](https://semver.org/), as `0.X.Y` until 1.0.0. Each is a GitHub release, and nothing is published outside GitHub before 1.0.0. A release's section is dated and filled in after its tag, so [Unreleased] lists every change that no release holds yet.

## [Unreleased]

## [0.1.0] - 2026-11-27

### Added

- `Stryker::VERSION`, the version of the gem.
- The `stryker` command, with `stryker run [configFile]`, `stryker help [command]`, `-h`, `--help`, and `--version`, a flag for every option, and the exit statuses 0, 1, 2, and 128 plus the signal's number. `stryker run` checks the configuration and then stops with status 2, because a run isn't built yet.
