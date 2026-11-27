---
status: proposed
date: 2026-11-26
deciders: "The project's architect, an AI agent, chose the mechanism ([#7](https://github.com/setdef/stryker_for_ruby/issues/7), [#8](https://github.com/setdef/stryker_for_ruby/issues/8)). It works within the owner's scope rulings: Linux, macOS, and Windows in the first release, with correct results preferred over fast ones ([#4](https://github.com/setdef/stryker_for_ruby/issues/4)), Minitest and RSpec adapters ([#5](https://github.com/setdef/stryker_for_ruby/issues/5)), and MRI only for version 1.0.0 ([#6](https://github.com/setdef/stryker_for_ruby/issues/6)). The rulings on the gem's name ([#1](https://github.com/setdef/stryker_for_ruby/issues/1)), the executable ([#2](https://github.com/setdef/stryker_for_ruby/issues/2)), and the configuration file ([#3](https://github.com/setdef/stryker_for_ruby/issues/3)) don't bear on this decision."
---

# Mutants are compiled into the code once and switched on at run time

## Context and Problem Statement

**Stryker (for Ruby)** runs the project's tests against each mutant, one mutant at a time, and each run should include only the tests that reach its mutant. Every mutant run happens in a clean process ([ADR 0002](0002-every-mutant-runs-in-a-clean-process.md)). On Windows, which has no `fork`, each of those processes loads the project from the start ([#4](https://github.com/setdef/stryker_for_ruby/issues/4)).

StrykerJS, Stryker.NET, and Stryker4s all use mutant schemata, also called mutation switching: each puts every mutant into the code once, behind a check of which mutant is active, instead of compiling the code again for each mutant. They share the concepts that follow from it, such as static mutants. The `mutant` gem instead evaluates one mutated method again in each forked child.

How do mutants get into the code, how is each run's set of tests found, and how does the changed code load?

## Decision Drivers

* Correct results come before fast ones ([#4](https://github.com/setdef/stryker_for_ruby/issues/4)), so the map from mutants to tests must have no false entries and miss no true ones, and the instrumented code must behave as the original with no mutant active.
* On Windows every run is a fresh process ([#4](https://github.com/setdef/stryker_for_ruby/issues/4)), so whatever a run does before its tests start is paid once per mutant.
* `__FILE__`, `__dir__`, `require_relative`, `caller_locations`, `Method#source_location`, and backtraces keep pointing at the project's files and lines ([#7](https://github.com/setdef/stryker_for_ruby/issues/7)).
* It works with Zeitwerk and with Bootsnap, which a new Rails 8.1 app sets up from its test helper ([#8](https://github.com/setdef/stryker_for_ruby/issues/8)).
* Instrumenting a large file costs little time and memory ([#7](https://github.com/setdef/stryker_for_ruby/issues/7)).

No other driver was recorded.

## Considered Options

1. **Mutant switching, with hits for coverage and a `load_iseq` hook for loading.**
2. **Evaluating each mutated method again in a forked child,** as the `mutant` gem does.
3. **Mutant switching with Ruby's `Coverage` library** in lines mode for the map from mutants to tests.
4. **Mutant switching with a sandbox copy** of the project first on `$LOAD_PATH`.
5. **Mutant switching with hooks on `require`, `require_relative`, and `load`.**

## Decision Outcome

Chosen: option 1. Prism parses each file. A mutator returns each mutant as a text edit on the original source, and the report shows that edit. The instrumenter splices a single-line switch around each mutation site into the original bytes: a ternary for one mutant, and `if`/`elsif` for several. A mutant branch holds the mutant's text with no switch inside it. When a mutant's text spans several lines, keeps a heredoc opener, or comes from an edit inside a heredoc's body, the instrumenter puts the mutant's text on one line with Prism and refract's converter and formatter, and when no one-line form exists, the site gets no mutant, and the run reports how many sites it skipped and why. So every line stays where it was. A mutant whose site can't hold a switch gets one on the nearest enclosing node that can, as StrykerJS's mutant placers do, and adjacent string literals joined by a backslash take their switch on the enclosing string node. The switch reads a constant that holds an object with an attribute reader. The map from mutants to tests, and the detection of static mutants, come from hits recorded through the same switches. Instrumented code loads through a `RubyVM::InstructionSequence.load_iseq` hook, which the loader keeps in front of Bootsnap, and the dry run fails if any instrumented file loaded without going through it.

It was chosen because the code is instrumented once and loaded once per process, so a run only sets which mutant is active, and because the switches give the map from mutants to tests with no second mechanism. Option 2 lost because each mutant is instrumented and evaluated separately, and each child pays for that, and on Windows each run would pay it in a fresh process. It also gives no map from mutants to tests without a separate mechanism. Option 3 lost because line coverage gave a wrong map in a probe. Options 4 and 5 lost on the faults a loading probe found, listed under Confidence.

Splicing won over running the whole file through refract's formatter ([#7](https://github.com/setdef/stryker_for_ruby/issues/7)). The formatted file kept the original line in 2 of 18 line checks, dropped the data after `__END__`, lost `# frozen_string_literal: true` in a file whose only strings are interpolated, and crashed on a named-capture `=~`. Moving its lines back through refract's source map kept all 18 lines but kept the other faults, and on the largest file it took 25 times as long as splicing with refract-formatted mutants, and 17 times the memory. Splicing as first probed copied every inner switch into each mutant branch, which turned the 95 KB of `resolv.rb` into 730 KB, and a multi-line site moved every later line. Mutant branches without inner switches, and mutants on one line, answer both.

The loader keeps the hook in front of Bootsnap by overriding `prepend` on `RubyVM::InstructionSequence.singleton_class` ([#8](https://github.com/setdef/stryker_for_ruby/issues/8)). Bootsnap's settings lost because none of them removes its module. Stubbing `bootsnap/setup` lost because it turns Bootsnap off for the whole project and misses a project that calls `Bootsnap.setup` or requires `bootsnap` directly. Prepending the hook again after the test helper lost because a Rails app loads files while its helper loads, and those would stay uninstrumented. Wrapping Bootsnap's module lost because it depends on the name of a module internal to Bootsnap, and covers no other library.

How it works is in [docs/contributors/design/mutant-placement.md](../design/mutant-placement.md), [docs/contributors/design/coverage.md](../design/coverage.md), and [docs/contributors/design/loading-and-isolation.md](../design/loading-and-isolation.md).

Confidence: probes show that option 1 works. On Ruby 3.3.11, 3.4.13, 4.0.10, and 4.1-dev, splicing passed 153 of 169 kinds of site, and splicing with refract-formatted mutants and no inner switches passed 155, with the same results on every version. The failures that every candidate shared are the sites that can't hold a switch. Recorded comparisons support "better". For the map, hits found all 76 true (test, mutant) pairs with no false ones, where `Coverage` in lines mode found 61, plus 35 false pairs, and missed 15. For loading, the hook kept every original path and worked with Zeitwerk, where a sandbox copy showed sandbox paths and loaded stale code from Bootsnap's cache, and `require` hooks failed with `NoMethodError` on Ruby 3.4 and later in a Zeitwerk project when installed before Bootsnap, and loaded a file twice on Windows. For producing the instrumented source, [#7](https://github.com/setdef/stryker_for_ruby/issues/7) holds the comparison given above. With the `prepend` override, the hook stayed in front of Bootsnap 1.26.2 on Ruby 3.4.13 and 4.0.10, with the same results on Windows with Ruby 4.0.10, and files that aren't instrumented still loaded through Bootsnap's cache ([#8](https://github.com/setdef/stryker_for_ruby/issues/8)). No comparison with option 2 was recorded; it lost on cost reasoning. The override also worked on Ruby 3.3.11 and 3.3.14 ([#8](https://github.com/setdef/stryker_for_ruby/issues/8)). Checking each mutant's plain mutant, the file with one edit, is what costs time in a large file ([#16](https://github.com/setdef/stryker_for_ruby/issues/16)), and a pool of parse workers shares it among the processors. With Ruby 4.0.10 and Prism 2.1.0, and mutants made as the probe made them, instrumenting `resolv.rb` (95 KB, 665 mutants) took 1.5 s on Linux and 3.4 s on Windows, `prism/node.rb` (990 KB, 835 mutants) took 2.4 s and 7.5 s, and `unicode_normalize/tables.rb` (229 KB, 17,279 mutants) took 51 s and 85 s. The pool started one worker for each 40 million bytes of work, one for each processor at most. In one process the three files took 1.5 s, 12.1 s, and 116.9 s on Linux, and 3.7 s, 21.2 s, and 242.4 s on Windows. The driver that instrumenting a large file costs little time holds for the first two files and not for the third, whose 17,279 mutants each cost a whole-file parse. Keeping instrumented files between runs, keyed by their content, would cost a file whose text hasn't changed no parse at all ([#16](https://github.com/setdef/stryker_for_ruby/issues/16)).

### Consequences

* Good, because a mutant run only sets the active mutant, so a forked child or a pool process starts its tests at once after load.
* Good, because the map from mutants to tests is exact on the probe, so a run never leaves out a test that reaches its mutant.
* Good, because comments, heredocs, magic comments, and the data after `__END__` stay as they were, and every line keeps its number.
* Bad, because every switch check runs in every test, even with no mutant active, so the project's tests run slower under **Stryker (for Ruby)** than without it. A hit costs about 17 to 66 ns only in the dry run, because a mutant run records no hits and `hit` returns at once.
* Bad, because some sites can't hold a switch. A mutant at such a site gets its switch at an enclosing node, and one that moves out to a `def` or to a statement in a class body becomes static, which costs a fresh process.
* Bad, because a site whose mutant has no one-line form gets no mutant, so no test is checked against a mistake there. The run reports how many such sites it skipped.
* Bad, because `load_iseq` exists only in CRuby, so **Stryker (for Ruby)** can't run on JRuby or TruffleRuby.
* Bad, because the loader changes how `prepend` behaves on `RubyVM::InstructionSequence.singleton_class` in every process that loads the project's code. Whenever a module that defines `load_iseq` is prepended after the hook, the loader prepends a new copy of the hook in front of it, so Bootsnap's two prepends stack two copies. The loading check stays, to catch an instrumented file that the override misses.
* Bad for maintainers, because the placement rules depend on Ruby's grammar, so each new Ruby version can add a kind of site that needs new rules.

### Confirmation

The instrumenter's tests run each kind of site from the placement design with no mutant active and with each mutant active, on every Ruby version in CI, and compare the output with the original code and with the plain mutant. The loader's tests check the `prepend` override on every Ruby version in CI: `LoaderTest` and `HookTest` on a stand-in for `RubyVM::InstructionSequence`, and `LoaderProcessTest` on the real class, where a `load_iseq` prepended after the hook, as Bootsnap prepends its own, still leaves the hook in front. `LoadingCheckTest` checks that the loading check lists each instrumented file that loaded without the hook, and names a module that got ahead of it. The dry run doesn't call the loading check yet, so no test runs it there.

## More Information

[#7](https://github.com/setdef/stryker_for_ruby/issues/7) holds the probes and the decision on producing instrumented source, and [#8](https://github.com/setdef/stryker_for_ruby/issues/8) the probes and the decision on Bootsnap. Revisit this decision if a Ruby release removes or changes `RubyVM::InstructionSequence.load_iseq`, or if Ruby gains a supported way to load changed source under a file's original path.
