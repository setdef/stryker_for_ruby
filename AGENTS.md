# AI Agent Instructions

@CONTRIBUTING.md

## Running the tools

- Run the repository's tools as `MISE_TRUSTED_CONFIG_PATHS=$PWD mise exec -- <command>`.
- Install gems with `BUNDLE_PATH` pointing outside the repository, and set it again for every `bundle exec`. RuboCop and `reuse lint` read gems installed in any folder inside the repository except `vendor/bundle`, which both skip.
- Don't run `bin/setup` in a git worktree. It installs a pre-commit hook, and every worktree of a clone shares the clone's hooks. Run `mise install` and `bundle install` instead.

## Weighing options

Judge each option for a decision against what it must serve: the requirements in the design documents, the drivers in the ADRs, and [the Tao](CONTRIBUTING.md#the-tao-of-stryker-for-ruby). Report which options you weighed and why each lost, and check each reason against the requirement it cites. Popularity counts for less than quality, what an option can do, and performance, such as speed and memory. When an option is popular, ask what its popularity stands for and what choosing it trades away.

## Questions for the maintainers

Put a question for the maintainers in a GitHub issue labeled `question`, assigned to the maintainer it's for. A backlog item that the question blocks links to it with a `#` reference, and is never labeled `question` itself. When the answer is no longer needed, unassign the maintainer and close the issue.

## Agents that delegate

An AI agent that hands work to other agents passes these rules on to them, and answers for their work: for each judgment call they make, each change they make to a Markdown file in the repository, and each recommendation they propose. When any of these is wrong, the agent fixes the work or reverts it.

