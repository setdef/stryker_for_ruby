---
status: proposed
date: 2026-11-26
deciders: "The project's architect, an AI agent, chose the rule ([#7](https://github.com/setdef/stryker_for_ruby/issues/7)). The owner's scope rulings ([#1](https://github.com/setdef/stryker_for_ruby/issues/1), [#2](https://github.com/setdef/stryker_for_ruby/issues/2), [#3](https://github.com/setdef/stryker_for_ruby/issues/3), [#4](https://github.com/setdef/stryker_for_ruby/issues/4), [#5](https://github.com/setdef/stryker_for_ruby/issues/5), and [#6](https://github.com/setdef/stryker_for_ruby/issues/6)) set what the gem must do, and none of them mentions a dependency."
---

# The processes that load the project's code load only Stryker (for Ruby)'s runtime, which depends on nothing outside the standard library

## Context and Problem Statement

**Stryker (for Ruby)** loads the project's code and tests into processes that run inside the project's bundle, so every gem those processes load resolves against the gem versions the project has locked. A constraint that conflicts with the project's gems makes **Stryker (for Ruby)** impossible to run there.

The instrumenter needs Prism to parse the project's files, refract to put a mutant that spans several lines on one line ([ADR 0001](0001-mutants-are-compiled-into-the-code-once-and-switched-on-at-run-time.md)), and Erubi's tag regexp to find the Ruby in ERB templates ([#9](https://github.com/setdef/stryker_for_ruby/issues/9)). refract 2.0.0 requires `prism >= 1.0` and any version of `zeitwerk`. It works with Prism 1.0.0 and later, and fails with Prism 0.30.0 and with Ruby 3.3's bundled Prism 0.19.0, so Ruby 3.3 needs the Prism gem ([#7](https://github.com/setdef/stryker_for_ruby/issues/7)).

Which of **Stryker (for Ruby)**'s code and dependencies load in the processes that load the project's code?

## Decision Drivers

* Every dependency resolves against the project's bundle ([#7](https://github.com/setdef/stryker_for_ruby/issues/7)).

No other driver was recorded.

## Considered Options

1. **Two kinds of process.** The orchestrator instruments, plans, and reports, and it alone loads Prism, refract, and Erubi. The processes that load the project's code load only the runtime (the hook, the switch, and the hit recorder), which uses nothing outside the standard library, and they read the instrumented source from a cache outside the project.
2. **One kind of process.** The instrumenter, with Prism, refract, and Erubi, loads in the processes that load the project's code.
3. **Prism only,** with a printer for mutated Prism nodes written in this repository in place of refract.

## Decision Outcome

Chosen: option 1, because every dependency resolves against the project's bundle, and under option 1 the processes that load the project's code load nothing for **Stryker (for Ruby)** outside the standard library. Option 2 lost on the same driver: it loads Prism, refract, and Zeitwerk beside the project's code. Option 3 lost to reusing refract, which already prints valid Ruby with precedence kept, and whose tests round-trip the standard library and installed gems ([#7](https://github.com/setdef/stryker_for_ruby/issues/7)).

Prism (`>= 1.0`), refract (`~> 2.0`, which brings Zeitwerk), and Erubi (`~> 1.13`, [#9](https://github.com/setdef/stryker_for_ruby/issues/9)) are dependencies of the gem, and they load only in the orchestrator. The cache is a temporary directory that the orchestrator makes with `Dir.mktmpdir` and deletes when the run ends. How it works is in [docs/design/loading-and-isolation.md](../design/loading-and-isolation.md#two-kinds-of-process).

Confidence: a probe shows that option 1 works ([#7](https://github.com/setdef/stryker_for_ruby/issues/7)). One process ran Prism, refract, and Zeitwerk 2.8.3 outside any bundle and wrote the instrumented source to a cache. A second process ran under `bundle exec`, with Zeitwerk pinned to `~> 2.6.0` and neither Prism nor refract in its bundle. It loaded the cached source through a `load_iseq` hook, never loaded Prism or refract, and loaded through Zeitwerk, recorded hits, and switched on active mutants, with every combination of Ruby 3.3 and 4.0 for the two processes. The instrumented output was byte-identical across Ruby 3.3 to 4.1-dev, Prism 1.5.3 to 2.1.0, and Zeitwerk 2.6.18 and 2.8.3. Bundler resolved and ran refract with Zeitwerk 2.6 and 2.8, and with Prism 1.x and 2.x, which is the evidence that the gem's constraints fit common bundles. No recorded comparison measures option 1 against option 2. Unproven: #7 records no run of the two processes on Windows.

### Consequences

* Good, because the processes that run the project's tests never load Prism, refract, Zeitwerk, or Erubi for **Stryker (for Ruby)**, so the project's code never runs beside a version of them that **Stryker (for Ruby)** needs.
* Good, because instrumented source never goes into the project's folders.
* Bad, because the gem still depends on `prism >= 1.0`, `refract ~> 2.0`, and `erubi ~> 1.13`, so a bundle that holds the gem has to resolve them, and a bundle that locks Prism below 1.0 can't hold the gem.
* Bad, because on Ruby 3.3, whose bundled Prism is 0.19.0, Bundler has to install the Prism gem.
* Bad, because the rule trades against the project's rule to reuse before building ([AGENTS.md](../../AGENTS.md)). Code that a gem would provide in the runtime is written and maintained in this repository, with this ADR as the written reason that rule asks for.
* Bad for maintainers, because a run has two kinds of process and a cache between them to build, test, and keep working, and the runtime has to work with any version of a default gem, such as `json`, that a project can lock and a supported Ruby can load.

### Confirmation

Nothing checks this decision yet. A reviewer reads every change to the gemspec's dependencies and to what the runtime requires.

## More Information

[#7](https://github.com/setdef/stryker_for_ruby/issues/7) holds the probes and the decision. [ADR 0001](0001-mutants-are-compiled-into-the-code-once-and-switched-on-at-run-time.md) records why mutants are compiled into the code once, which is what the instrumenter produces.
