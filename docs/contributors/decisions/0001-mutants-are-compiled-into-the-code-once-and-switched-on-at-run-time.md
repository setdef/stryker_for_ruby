---
status: accepted
date: 2026-11-27
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

Chosen: option 1. The instrumenter puts every mutant of a file into the file's code once, each behind a switch that reads which mutant is active. The map from mutants to tests, and the detection of static mutants, come from hits recorded through the same switches. Instrumented code loads through a `RubyVM::InstructionSequence.load_iseq` hook. The loader keeps the hook in front of Bootsnap, and of any other library that prepends a `load_iseq` later, by overriding `prepend` on `RubyVM::InstructionSequence.singleton_class`. A loading check lists each instrumented file that loaded without going through the hook, and is meant to end the dry run ([The loading check](../design/loading-and-isolation.md#the-loading-check)).

It was chosen because the code is instrumented once and loaded once per process, so a run only sets which mutant is active, and because the switches give the map from mutants to tests with no second mechanism. Option 2 lost because each mutant is instrumented and evaluated separately, and each child pays for that, and on Windows each run would pay it in a fresh process. It also gives no map from mutants to tests without a separate mechanism. Option 3 lost because line coverage gave a wrong map in a probe. Options 4 and 5 lost on the faults a loading probe found, listed under Confidence.

How it works is in [docs/contributors/design/mutant-placement.md](../design/mutant-placement.md), [docs/contributors/design/coverage.md](../design/coverage.md), and [docs/contributors/design/loading-and-isolation.md](../design/loading-and-isolation.md).

Confidence: probes show that option 1 works. On Ruby 3.3.11, 3.4.13, 4.0.10, and 4.1-dev, the probe's instrumenter, which splices each switch into the file's original bytes ([Splicing into the original bytes](../design/mutant-placement.md#splicing-into-the-original-bytes)), passed 153 of 169 kinds of site. It passed 155 when it also put each mutant's text on one line with refract and left switches out of the text ([The mutant adds no line break](../design/mutant-placement.md#the-mutant-adds-no-line-break)). The results were the same on every version. The failures that every variant shared are the sites that can't hold a switch. Recorded comparisons support "better". For the map, hits found all 76 true (test, mutant) pairs with no false ones, where `Coverage` in lines mode found 61, plus 35 false pairs, and missed 15. For loading, the hook kept every original path and worked with Zeitwerk, where a sandbox copy showed sandbox paths and loaded stale code from Bootsnap's cache, and `require` hooks failed with `NoMethodError` on Ruby 3.4 and later in a Zeitwerk project when installed before Bootsnap, and loaded a file twice on Windows. With the `prepend` override, the hook stayed in front of Bootsnap 1.26.2 on Ruby 3.4.13 and 4.0.10, with the same results on Windows with Ruby 4.0.10, and files that aren't instrumented still loaded through Bootsnap's cache ([#8](https://github.com/setdef/stryker_for_ruby/issues/8)). The override also worked on Ruby 3.3.11 and 3.3.14 ([#8](https://github.com/setdef/stryker_for_ruby/issues/8)). No comparison with option 2 was recorded; it lost on cost reasoning. With Ruby 4.0.10 and Prism 2.1.0, and mutants made as the probe made them, instrumenting `resolv.rb` (95 KB, 665 mutants) took 1.5 s on Linux and 3.4 s on Windows, `prism/node.rb` (990 KB, 835 mutants) took 2.4 s and 7.5 s, and `unicode_normalize/tables.rb` (229 KB, 17,279 mutants) took 51 s and 85 s ([#16](https://github.com/setdef/stryker_for_ruby/issues/16)). The driver that instrumenting a large file costs little time holds for the first two files and not for the third, whose 17,279 mutants each cost a whole-file parse.

### Consequences

* Good, because a mutant run only sets the active mutant, so a forked child or a fresh process starts its tests at once after load.
* Good, because the map from mutants to tests is exact on the probe, so a run never leaves out a test that reaches its mutant.
* Good, because comments, heredocs, magic comments, and the data after `__END__` stay as they were, and every line keeps its number.
* Bad, because every switch check runs in every test, even with no mutant active, so the project's tests run slower under **Stryker (for Ruby)** than without it. A hit costs about 17 to 66 ns only in the dry run, because a mutant run records no hits and `hit` returns at once.
* Bad, because some sites can't hold a switch. A mutant at such a site gets its switch at an enclosing node, and one that moves out to a `def` or to a statement in a class body becomes static, which costs a fresh process.
* Bad, because a site whose mutant's text can't be put on one line gets no mutant ([The mutant adds no line break](../design/mutant-placement.md#the-mutant-adds-no-line-break)), so no test is checked against a mistake there.
* Bad, because `load_iseq` exists only in CRuby, so **Stryker (for Ruby)** can't run on JRuby or TruffleRuby.
* Bad, because the loader changes how `prepend` behaves on `RubyVM::InstructionSequence.singleton_class` in every process that loads the project's code. Whenever a module that defines `load_iseq` is prepended after the hook, the loader prepends a new copy of the hook in front of it, so Bootsnap's two prepends stack two copies. The loading check stays, to catch an instrumented file that the override misses.
* Bad for maintainers, because the placement rules depend on Ruby's grammar, so each new Ruby version can add a kind of site that needs new rules.

### Confirmation

The site tests, through `assert_site` in `test/support/site_case.rb`, run each kind of site from the placement design with no mutant active and with each mutant active, and compare the output with the original code and with the plain mutant. `RecorderBucketsTest`, `StaticHitsTest`, and `DryRunTest` check that each hit lands in the bucket of the test that reached the mutant, or in the static bucket. `LoaderTest` and `HookTest` check the hook and the `prepend` override on a stand-in for `RubyVM::InstructionSequence`, and `LoaderProcessTest` checks them on the real class, where a `load_iseq` prepended after the hook, as Bootsnap prepends its own, still leaves the hook in front. `BootsnapTest` checks, with Bootsnap itself, that the hook stays in front of Bootsnap's module with a compile cache and without one, and that a file that isn't instrumented still loads through Bootsnap's cache. `LoadingCheckTest` checks that the loading check lists each instrumented file that loaded without the hook, and names a module that got ahead of it. `DryRunTestsTest` checks the loading check in the dry run: the dry run calls it after its tests, and a failed check is the dry run's error. CI runs them in the gate on Ruby 4.0 and on Ruby's development version, on Linux, macOS, and Windows.

## More Information

[#7](https://github.com/setdef/stryker_for_ruby/issues/7) holds the probes and the decision on producing instrumented source, and [#8](https://github.com/setdef/stryker_for_ruby/issues/8) the probes and the decision on Bootsnap. Revisit this decision if a Ruby release removes or changes `RubyVM::InstructionSequence.load_iseq`, or if Ruby gains a supported way to load changed source under a file's original path.
