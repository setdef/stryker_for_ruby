# Contributor documentation

These pages are for the people and agents who change **Stryker (for Ruby)**. They say how the code works inside, why it is built that way, and how the repository's continuous integration (CI) checks each change. The documentation for people who use the tool is in [the README](../../README.md) and [the configuration page](../configuration.md).

- [Working rules](../../CONTRIBUTING.md): the rules for every change, covering the trunk, commit messages, tests, documentation, security, and licenses. Read it before your first commit.
- [Design](design/README.md): how each part of the code works, and the traps each part has to avoid. Start here to change the code.
- [Decisions](decisions/README.md): the architecture decisions that the structure rests on, each with the options weighed. Start here to ask why the code is shaped as it is.

## Continuous integration

GitHub runs `.github/workflows/fast.yml` on every push and pull request, with the gate on Ubuntu with Ruby 4.0 and the tests on Windows, and runs `.github/workflows/ci.yml` on every push to `trunk`, with the gate on Ruby 4.0 and the development version of Ruby on Linux, macOS, and Windows. The build cop, `.github/workflows/build-cop.yml`, finds the commit that turned a run of `fast.yml` or `ci.yml` on `trunk` red, runs the run's failed jobs again, and reverts the commit once the repository variable `BUILD_COP_REVERT` is true. The comment at the top of each of the three files describes it in full.
