# Design

These pages describe how **Stryker (for Ruby)** works inside, as the code on `trunk` does it: what each part does, how the parts fit together, and the traps each part has to avoid. They are for people and agents who change the code. Each page has one subject. The pages describe the code as it is, and the issues hold what is planned: a change that adds or changes behavior updates its page in the same commit as the code. When the code and a page disagree, one of them is wrong, and the change that fixes it updates both.

Why the design is the way it is, where that rests on an architecture decision, is in [the decision log](../decisions/README.md). A page here cites a decision by its number.

Start with the architecture page, which lists the parts and links to the page for each. It changes only when the structure does: the stages, the kinds of process, the ports, the domain events, and where each responsibility lives. A value's fields, an option's type, and an adapter's behavior are kept where they are maintained, in the RBS documentation of the code and in the page whose subject they are, such as [Test runners](test-runners.md) and [Configuration](../../configuration.md).

- [Architecture](architecture.md): the pipeline of a run, the ports and their adapters, the values and events that pass between the parts, and where each responsibility lives.
- [Loading and isolation](loading-and-isolation.md): the orchestrator and the project processes, the cache of instrumented source, the `load_iseq` hook that serves it and stays ahead of Bootsnap, the check that every instrumented file came through the hook, the pool of parse workers that checks each mutant is valid Ruby, the fresh process that each static mutant run gets and how a run's outcome becomes a status, and how the active mutant and the hook work with Ractors.
- [Mutators](mutators.md): the catalog of mutators and the exact pairs each one makes, the mutators that run when nothing is configured, the sites that get no mutant, and the equivalent mutants the mutators avoid.
- [Mutant placement](mutant-placement.md): the text edit each mutator returns, how the instrumenter splices each mutant's switch into the original source and keeps every line where it was, and the kinds of site that hold a switch.
- [Coverage](coverage.md): how the switches record which tests reach each mutant, how the recorder tells static mutants from runtime ones, how a hit made in a Ractor is recorded, and why Ruby's `Coverage` library doesn't do this.
- [Test runners](test-runners.md): how the Minitest adapter lists a project's tests and runs a chosen set of them one at a time, which of Minitest's internals it depends on and why, and what it does with retries, hooks, and `minitest/autorun`.
- [Ruby 3.3 and 3.4](../../older-ruby.md): the versions that aren't supported but aren't blocked, and the problems found on them.
