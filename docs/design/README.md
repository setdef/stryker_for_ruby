# Design

These pages specify how **Stryker (for Ruby)** works inside: what each part does, how the parts fit together, and the traps each part has to avoid. They are for people and agents who change the code. Each page has one subject, and the code is built to match it. When the code and a page disagree, one of them is wrong, and the change that fixes it updates both.

Why the design is the way it is, where that rests on an architecture decision, is in [the decision log](../decisions/README.md). A page here cites a decision by its number.

Start with the architecture page, which lists every part and links to the page for each.

- [Architecture](architecture.md): the pipeline of a run, the ports and their adapters, the values and events that pass between the parts, and where each responsibility lives.
- [Loading and isolation](loading-and-isolation.md): the `load_iseq` hook that serves instrumented code, the check that every instrumented file came through it, and the clean process each mutant run gets on Linux, macOS, and Windows.
- [Coverage](coverage.md): how the dry run records which tests reach each mutant, how it finds static mutants, and why Ruby's `Coverage` library doesn't do this.
