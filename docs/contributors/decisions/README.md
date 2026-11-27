# Architecture decisions

Each file in this folder records one architecture decision: a choice that the structure of **Stryker (for Ruby)** rests on, and that would take a rewrite of a large part of the code to undo. A record gives the problem, the options weighed, the reasons for the choice, and what it costs. How the chosen design works is in [the design documents](../design/README.md).

The records follow [MADR](https://adr.github.io/madr/) 4.0.0. A record's status is `proposed` until the code does what it says, and `accepted` from then on. A record that stops being true is replaced by a new record with the next number and deleted, so every record here is current. Numbers are never reused.

The keeper of this log writes and numbers the records. Anyone else who needs a decision recorded describes it in an issue, with its options and evidence, for the keeper to record.

| Number | Decision | Status |
| - | - | - |
| [0001](0001-mutants-are-compiled-into-the-code-once-and-switched-on-at-run-time.md) | Mutants are compiled into the code once and switched on at run time. | proposed |
| [0002](0002-every-mutant-runs-in-a-clean-process.md) | Every mutant runs in a clean process. | proposed |
| [0003](0003-the-processes-that-load-the-projects-code-load-only-stryker-for-rubys-runtime-which-depends-on-nothing-outside-the-standard-library.md) | The processes that load the project's code load only **Stryker (for Ruby)**'s runtime, which depends on nothing outside the standard library. | proposed |
