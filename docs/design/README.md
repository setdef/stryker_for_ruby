# Design

These pages specify how **Stryker (for Ruby)** works inside: what each part does, how the parts fit together, and the traps each part has to avoid. They are for people and agents who change the code. Each page has one subject, and the code is built to match it. When the code and a page disagree, one of them is wrong, and the change that fixes it updates both.

Why the design is the way it is, where that rests on an architecture decision, is in [the decision log](../decisions/README.md). A page here cites a decision by its number.

Start with the architecture page, which lists every part and links to the page for each.

- [Architecture](architecture.md): the pipeline of a run, the ports and their adapters, the values and events that pass between the parts, and where each responsibility lives.
- [Loading and isolation](loading-and-isolation.md): the orchestrator and the project processes, the cache of instrumented source, the `load_iseq` hook that serves it and stays ahead of Bootsnap, the check that every instrumented file came through the hook, the clean process each mutant run gets on Linux, macOS, and Windows, and how the active mutant, the hook, and forking work with Ractors.
- [Mutant placement](mutant-placement.md): the text edit each mutator returns, how the instrumenter splices each mutant's switch into the original source and keeps every line where it was, and the kinds of site that hold a switch.
- [ERB templates](erb.md): which files are templates (names that end in `.erb`), how the extractor finds the Ruby in an ERB template with Erubi's regexp, where mutants go in a template, how the instrumented text reaches Rails, stdlib `ERB`, Erubi, and Tilt, and the templates that load uninstrumented.
- [Coverage](coverage.md): how the dry run records which tests reach each mutant, how it finds static mutants, how a hit made in a Ractor is recorded, and why Ruby's `Coverage` library doesn't do this.
