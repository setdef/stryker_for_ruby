# Working on Stryker (for Ruby)

## The Tao of Stryker (for Ruby)

Tests should catch bugs. Mutation testing checks whether they do. It makes a small change to the code, the kind of mistake a programmer makes, and runs the tests. If no test fails, the tests would have missed that bug.

**Stryker (for Ruby)** does this for Ruby and ERB projects, whoever wrote the code. Each mutant that survives shows you something: a test to write, a test to strengthen, or code to remove.

It must tell the truth. A mutant survives only if the tests really ran against it and really passed. **Stryker (for Ruby)** changes nothing in your project, and it fails loudly rather than guess.

It is a Stryker. It uses the same names, scores, reports, and dashboard as the other Stryker tools, so the Stryker Mutator organization can adopt it.

These are the working rules for everyone who changes this repository: people, and the AI agents they run. They are the project's shared rules, so they apply to every contributor's agents alike.

## What the project is

**Stryker (for Ruby)** inserts bugs, called mutants, into your source code one at a time, runs your tests against each, and reports every mutant that no test caught.

It is a community port of [Stryker Mutator](https://stryker-mutator.io), with no affiliation to that project. The maintainers hope to make it an official project of the [Stryker Mutator organization](https://github.com/stryker-mutator), next to [StrykerJS](https://github.com/stryker-mutator/stryker-js), [Stryker.NET](https://github.com/stryker-mutator/stryker-net), and [Stryker4s](https://github.com/stryker-mutator/stryker4s). Those projects show how Stryker behaves in other languages.

In Markdown prose, write the name as `**Stryker (for Ruby)**`. In plain text, write `Stryker (for Ruby)`. The repository and the gem are `stryker_for_ruby`, the constant is `Stryker`, and the require is `require "stryker"`.

## Committing to the trunk

The project practices trunk-based development.

- **Run the tests freshly:** Delete `coverage/` first, then run `rake test:ruby` with `mise exec ruby@4.0.10`, using a separate `BUNDLE_PATH`.
- **Check code or tests that behave differently on Windows on Windows.** This covers anything that reads `File::ALT_SEPARATOR` or `Gem.win_platform?`, and anything that depends on paths, line endings, `fork`, or signals.
- **Check a change to `.github/workflows/*.yml`** by loading the file with `YAML.safe_load_file` and running each changed `run:` string exactly as YAML parsed it.

- **When the push is refused because `trunk` moved,** read the diff, rebase, run the gate again if risky, and push again. Read the diff every time, even when the incoming commit messages look unrelated: two changes can rebase cleanly and still break each other.
- **After you push, wait for nothing.** Don't watch a CI/Proof run or poll for its result. Check work before the push, not after it.
- **Keep every push releasable.** When a goal takes several commits, hide the unfinished code behind a feature flag or build it by branch by abstraction, and land it in slices.
- **Every agent pushes the commits it wrote immediately.** Nobody collects other agents' commits to land them, nobody sets a landing order or asks others to stop pushing, and nobody keeps working with gate-passing unpushed commits.
- **Fix or quarantine a flaky test right away,** recording the reason, instead of rerunning it until it passes. Never delete or disable a test to make the build faster.
- **Review on origin.** Review never blocks a push that passes the gate, because follow-up commits and reverts handle feedback.

## Spikes

A spike, prototype, or probe is throwaway code. It never reaches `trunk`, and nobody pushes it anywhere else either, except a probe that needs CI's runners, which may go on a throwaway branch with a maintainer's permission. When it's done and you've [written things down](#writing-things-down) delete the spike. Write production code afresh after the decision, and never grow it from a spike.

## Commit messages

Write every commit message in the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) format: `<type>(<scope>): <description>`, or `<type>: <description>` with no scope.

- The type is one of `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, or `revert`, in lowercase.
- The scope is optional. It is the part of the code the change affects, in lowercase.
- The description is a short summary in the imperative mood ("add", not "added" or "adds"), with no period at the end.
- A body, after a blank line, explains why this implementation was chosen over others. It never re-states the diff or explains anything obvious from reading the patch.
- A breaking change has a `BREAKING CHANGE: <description>` footer.
- An agent commit has a `Co-authored-by: <model-and-version>` footer.

For example: `feat(mutators): add a string literal mutator`, or `docs: describe the configuration file`.

## Writing code

- **Get each fact from its source.** Run the tool, read the current documentation or source, or read a run's result. This matters most for facts that depend on a version, such as a gem's API, Prism's node types, or how Ruby behaves in a given version, because memory about a dependency goes stale, especially for projects that change often. Never pass on another agent's or a tool's claim as fact without checking it, and say which facts you checked and which you didn't.
- **Reuse before you build.** The project carries as little code as it can. Before you write a parser, protocol, server, format reader, cryptographic primitive, or anything else of that kind, look for reliable code that already exists: the Ruby standard library first, then gems that are maintained, documented, and tested. Code written for this repository in place of a library needs the same written reason that a new dependency does.
- **Code is a liability.** The more code the project carries, the more can go wrong and the harder it is to maintain.
- **Improve software design** according to the Boy Scout Rule, with refactors in a separate commits before implementation. Make the change easy (warning: this may be hard), then make the easy change.
- **TDD tests every change in behavior.** Confirm that each new test fails without the change: a test that passes either way proves nothing.
- **Update the user documentation** in the same commit as a change to anything users see. Watch your prose style, and use best practices for developer docs.
- **Write the doc comment** for every public class, module, constant, and method in the matching `.rbs` declaration in `sig/`. A comment directly above a `def`, `class`, or `module` in `lib/` would be RDoc documentation, which doesn't go in `.rb` files. Don't leave commented-out code, history notes, or decorative divider comments in the source.
- **Comment why, not what.** Rename a variable or extract a method instead of explaining unclear code. Write a comment for a reason the code can't show, such as a constraint from outside the project or the choice of an algorithm. Therefore, `.rb` files should have very few comments.

## Writing things down

Record these where the next contributor will find it. (What lives only in a chat, or on one machine, gets lost.) Write each thing in its axis's home, and nowhere else:

| Axis | As it is | As it will be |
| - | - | - |
| Requirements: what the software does for its users | User documentation† | Issues |
| Contract: what a caller can rely on | Doc comments; the changelog, for changes over time | Issues |
| Architecture: the few decisions the structure rests on | Accepted ADRs | Proposed ADRs |
| Design: how each part works, and why | Design documents | Nowhere |
| Behavior: what the code does | Tests | Nowhere |
| Facts that constrain the design | The design document or ADR they constrain; until that exists, the issue whose work they constrain | Nowhere |

- **Decide a design at the last responsible moment,** while building it, with the facts in hand, then record it as it is. Never write a design, or a behavior, ahead of the code, in an issue or anywhere else.
- **A design document explains a part to the people who change it:** its concepts, how its pieces fit, why it is shaped this way, its traps, and what it deliberately doesn't do. It doesn't restate the code: no fields, option types, step-by-step restatements of the code, or private call graphs.
- **Change a design document when a design decision changes,** never because behavior did. The two vary independently.
- **A doc comment describes the contract from the caller's side,** never how the code does the work inside.
- **Check a fact at its source before anything rests on it,** on the platform it's about. A decision that rests on an unchecked fact waits.
- **Record a fact found before its design exists as a fact, not a decision:** what was spiked or checked, how, on which platform and version, and the result. It waits in the issue whose work it constrains. When the design or architecture is decided, the relevant facts go in that design document or ADR.
- **Issues may represent proposed or accepted** requirements or contracts, and an issue that doesn't specify which can't be assumed to have already been accepted or denied.
- † **In a project being built under README-Driven Development,** the user documentation is written ahead of the code, as its requirements. Everywhere else, it describes only what the software does today.

## Security

**Stryker (for Ruby)** runs other people's test suites and reads and writes their files, so treat every path, setting, and line of output that comes from them as untrusted input.

- Start a subprocess with an array of arguments, never a single string a shell would parse.
- Build file paths from parts with `File.join` or `Pathname`, and check that a path built from outside input stays inside the directory you meant it for.
- Never hardcode a secret, such as an API key. Read it from an environment variable.
- Never call `Marshal.load` or `YAML.unsafe_load` on data from outside the process.
- Commits, issues, comments, docs, and code hold only what anyone could find in public sources. Never put in them your machine's names, paths, or hardware, or anything said in a private conversation, and never quote a person from one. An ADR lists its deciders by role, with links to the public issues.

## Quality gates

`bundle exec rake` runs the quality gates: RubyCritic, RuboCop, Steep, test coverage, documentation coverage, `docs:placement` (which fails on a doc comment in a `.rb` file), and `reuse lint`. Every change has to pass all of them, with zero errors and zero warnings. Their thresholds only ever go up. When a change fails a gate, fix the change; never lower a threshold, turn off a check, or exclude code to get it through.

Coverage is 100% for each file, on every system in CI. A test skipped on one system can drop that system's branch coverage below 100% and turn its job red, even though every test passes. Never skip a test on one system to make it pass. Pass the system-dependent value in, such as a path separator or a platform flag, so the test runs everywhere.

When a gate (a RubyCritic score, a Reek smell, a RuboCop length limit) pushes the design, it's actually pushing you to remember OOA&D & OOP best practices. They properly flag bad code, but their suggestions are naive. Don't game them or comply naively; take responsibility for the object design improving over time.

### What the maintainers decide

Ask the maintainer before you change any of these:

- product scope
- licensing
- significant changes to UX/DX (commands, flags, environment variables, file formats, etc).
- anything that changes the Stryker Mutator organization's projects or communicates with that organization

## Copyright and licenses

The project follows the [REUSE Specification](https://reuse.software/spec-3.3/). SPDX headers in files are only for content under a copyleft or share-alike license. Snippet comments are used for ported code, complying with their license. Examples in documentation also use Snippet comments, MIT-0. `REUSE.toml` holds the license information for content under a permissive or public-domain license. The project's own files are Apache-2.0, which is permissive, so they have no SPDX headers; `REUSE.toml` covers them.

A file under a copyleft or share-alike license must not be copied from elsewhere without permission from the maintainer. An approved copyleft or share-alike file, or a file copied under a permissive or public-domain license, has that license in its own SPDX header. Run `reuse lint` before you push when copying or porting code.

Code ported from another project (an algorithm translated into Ruby, a table, a regex, etc.), as opposed to code only inspired by it, goes between `# SPDX-SnippetBegin` and `# SPDX-SnippetEnd` comments in its file. Inside them, give the upstream license as `SPDX-License-Identifier`, the upstream copyright as `SPDX-SnippetCopyrightText`, and an `SPDX-SnippetComment` that names the upstream project and file and says what the port changed. `reuse lint` must still pass.

