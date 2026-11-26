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

The project supports Ruby 4.0 and later. Ruby 3.3 and 3.4 may work but are unsupported, and their known issues are listed in [`docs/older-ruby.md`](docs/older-ruby.md). The project's owner ruled in [#6](https://github.com/setdef/stryker_for_ruby/issues/6) that version 1.0.0 runs on CRuby (MRI) only. Write code that runs on Ruby 4.0.

## Committing to the trunk

The project practices trunk-based development. `trunk` is the only long-lived branch, and every change lands on it directly, one commit at a time, many times a day.

1. Run `git fetch`, then `git rebase origin/trunk`.
2. Make one change that keeps every check passing and could ship on its own.
3. Run the pre-push gate.
4. Push straight to `trunk`, and start the next change. A change is done when it is on `trunk`.

Keep the pre-push gate to about a minute. It runs the linters, the type checker, and the tests your change can affect, chosen by tooling that follows the code's dependencies, never by reading the diff. Where no tool can select tests that way, run the full suite. A slow or unreliable gate is a defect to fix, never a reason to skip a check, move it to after the push, or batch commits so that it runs once for several.

- **When the push is refused because `trunk` moved,** rebase, run the gate again, and push again. Rerun it every time, even when the incoming commits look unrelated: two changes can rebase cleanly and still break each other.
- **After you push, wait for nothing.** Don't watch a CI run or poll for its result. Check work before the push, not after it.
- **Keep every push releasable.** When a goal takes several commits, hide the unfinished code behind a feature flag or build it by branch by abstraction, and land it in slices.
- **Every agent pushes the commits it wrote.** Nobody collects other agents' commits to land them, and nobody sets a landing order or asks others to stop pushing.
- **Branches are rare and short.** Your local commits not yet on `trunk` are a branch, and they should exist for minutes. Any branch has one writer, lasts two days at most, and sends its commits to `trunk` and nowhere else. Never merge another person's or agent's branch into yours.
- **Warn everyone working in the repository before you change what others depend on,** such as a method many callers use. Name what will change, then make the change.
- **When `trunk` is broken, revert the breaking commit at once,** whoever wrote it, and tell its author. The author lands the fix again once it's ready.
- **Fix or quarantine a flaky test right away,** recording the reason, instead of rerunning it until it passes. Never delete or disable a test to make the build faster.
- **Review follows the landing.** A reviewer with no part in the change or its brief reads it soon after it lands, and answers with a follow-up commit or a revert.
- **Agents don't release.** An agent never tags a commit, publishes a gem, or creates a release branch. "Ship it" means land the change on `trunk`.

## Spikes

A spike, prototype, or probe is throwaway code. It never reaches `trunk`, and nobody pushes it anywhere else either, except a probe that needs CI's runners, which may go on a throwaway branch with a maintainer's permission. When it's done, only its findings land: as a design note, as a fact in a guide, or as a decision reported for an ADR. Then delete the spike.

Decide the structure before you build it. Never build a slice of production code to find out what the structure should be. Write production code afresh after the decision, and never grow it from a spike.

## Commit messages

Write every commit message in the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) format: `<type>(<scope>): <description>`, or `<type>: <description>` with no scope.

- The type is one of `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, or `revert`, in lowercase.
- The scope is optional. It is the part of the code the change affects, in lowercase.
- The description is a short summary in the imperative mood ("add", not "added" or "adds"), with no period at the end.
- A body, after a blank line, explains what changed and why.
- A breaking change has a `BREAKING CHANGE: <description>` footer.

For example: `feat(mutators): add a string literal mutator`, or `docs: describe the configuration file`.

## Writing code

- **Reuse before you build.** The project carries as little code as it can. Before you write a parser, protocol, server, format reader, cryptographic primitive, or anything else of that kind, look for reliable code that already exists: the Ruby standard library first, then gems that are maintained, documented, and tested. Code written for this repository in place of a library needs the same written reason that a new dependency does.
- **Get each fact from its source.** Run the tool, read the current documentation or source, or read CI's result. This matters most for facts that depend on a version, such as a gem's API, Prism's node types, or how Ruby behaves in a given version, because memory about a dependency goes stale, especially for projects that change often. Never pass on another agent's or a tool's claim as fact without checking it, and say which facts you checked and which you didn't.
- **Keep each change to what its task needs,** and match the style of the code around it. Put a refactor in a separate commit.
- **Test every change in behavior.** Confirm that each new test fails without the change: a test that passes either way proves nothing.
- **Update the user documentation** in the same commit as a change to anything users see.
- **Comment why, not what.** Rename a variable or extract a method instead of explaining unclear code. Write a comment for a reason the code can't show, such as a constraint from outside the project or the choice of an algorithm. Write the doc comment for every public class, module, constant, and method in the matching `.rbs` declaration in `sig/`, and keep `.rb` files to comments that say why the code is written as it is or warn about something tricky. A comment directly above a `def`, `class`, or `module` in `lib/` is RDoc documentation, so put it inside the body. Don't leave commented-out code, history notes, or decorative divider comments in the source.

## Security

**Stryker (for Ruby)** runs other people's test suites and reads and writes their files, so treat every path, setting, and line of output that comes from them as untrusted input.

- Start a subprocess with an array of arguments, never a single string a shell would parse.
- Build file paths from parts with `File.join` or `Pathname`, and check that a path built from outside input stays inside the directory you meant it for.
- Never hardcode a secret, such as an API key. Read it from an environment variable.
- Never call `Marshal.load` or `YAML.unsafe_load` on data from outside the process.
- Commits, issues, comments, docs, and code hold only what anyone could find in public sources. Never put in them your machine's names, paths, or hardware, or anything said in a private conversation, and never quote a person from one. An ADR lists its deciders by role, with links to the public issues.

## Running the tools

- Run the repository's tools as `MISE_TRUSTED_CONFIG_PATHS=$PWD mise exec -- <command>`.
- Install gems with `BUNDLE_PATH` pointing outside the repository, and set it again for every `bundle exec`. RuboCop and `reuse lint` read gems installed in any folder inside the repository except `vendor/bundle`, which both skip.
- Don't run `bin/setup` in a git worktree. It installs a pre-commit hook, and every worktree of a clone shares the clone's hooks. Run `mise install` and `bundle install` instead.

## Quality gates

`bundle exec rake` runs the quality gates: RubyCritic, RuboCop, Steep, test coverage, documentation coverage, `docs:placement` (which fails on a doc comment in a `.rb` file), and `reuse lint`. Every change has to pass all of them, with zero errors and zero warnings. Their thresholds only ever go up. When a change fails a gate, fix the change; never lower a threshold, turn off a check, or exclude code to get it through.

## Architecture decisions

The project records its architecture decisions as Architecture Decision Records (ADRs), in [`docs/decisions/`](docs/decisions/README.md). Most decisions don't earn an ADR. A decision does when the system's structure rests on it and undoing it would mean rewriting a large part of the code. How the code works, including the detail of a decision that has an ADR, goes in the design documents in [`docs/design/`](docs/design/README.md), which the code is built to match.

One keeper writes the ADRs: the keeper decides which decisions earn a record, writes each one, and numbers them. Everyone else, people and agents, writes no ADR. Instead, report to the keeper each decision your work needs, with the options you weighed and the evidence for each, and each line of an existing ADR that your change makes untrue.

When your change departs from an ADR in a technical way, push it anyway, and report the departure to the keeper. The keeper then records the changed decision, or the change is reverted. The decisions in [What the maintainers decide](#what-the-maintainers-decide) are the exception.

### Weighing options

Judge each option for a decision against what it must serve: the requirements in the design documents, the drivers in the ADRs, and [the Tao](#the-tao-of-stryker-for-ruby). Report which options you weighed and why each lost, and check each reason against the requirement it cites. Popularity counts for less than quality, what an option can do, and performance, such as speed and memory. When an option is popular, ask what its popularity stands for and what choosing it trades away.

### What the maintainers decide

Ask the maintainers before you change any of these:

- the public interface: commands, flags, exit statuses, environment variables, file formats, and output fields and their format
- product scope
- licensing
- anything that changes the Stryker Mutator organization's projects or communicates with that organization

### Recording decisions

Record every decision where the next contributor will find it: the issue it settles, a design page, an ADR, or the RBS documentation of the code. A decision that lives only in a chat, or on one machine, is lost.

## Questions for the maintainers

Put a question for the maintainers in a GitHub issue labeled `question`, assigned to the maintainer it's for. A backlog item that the question blocks links to it with a `#` reference, and is never labeled `question` itself. When the answer is no longer needed, unassign the maintainer and close the issue.

## Agents that delegate

An AI agent that hands work to other agents passes these rules on to them, and answers for their work: for each judgment call they make, each change they make to a Markdown file in the repository, and each recommendation they propose. When any of these is wrong, the agent fixes the work or reverts it.

## Copyright and licenses

The project follows the [REUSE Specification](https://reuse.software/spec-3.3/). SPDX headers in files are only for content under a copyleft or share-alike license, and snippet comments for ported code. `REUSE.toml` holds the license information for content under a permissive or public-domain license. The project's own files are Apache-2.0, which is permissive, so they have no SPDX headers. `REUSE.toml` covers them with one annotation for every path (`**`), with the copyright `2026 setdef` and the license `Apache-2.0`. The license text is in `LICENSES/Apache-2.0.txt`.

A file copied from elsewhere under a copyleft or share-alike license has that license in its own SPDX header, and its license text goes in `LICENSES/`. A file copied under a permissive or public-domain license gets an annotation in `REUSE.toml` that lists its copyright and license. Run `reuse lint` before you push.

Code ported from another project (an algorithm translated into Ruby, a table, a regex, etc.), as opposed to code only inspired by it, goes between `# SPDX-SnippetBegin` and `# SPDX-SnippetEnd` comments in its file. Inside them, give the upstream license as `SPDX-License-Identifier`, the upstream copyright as `SPDX-SnippetCopyrightText`, and an `SPDX-SnippetComment` that names the upstream project and file and says what the port changed. Add the upstream license's text to `LICENSES/` if it isn't there yet. `reuse lint` must still pass.
