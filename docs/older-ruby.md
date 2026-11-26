# Ruby 3.3 and 3.4

**Stryker (for Ruby)** supports Ruby 4.0 and later. Ruby 3.3 and 3.4 are unsupported. Nothing blocks them: the gem installs on them and runs, and you use them at your own risk. On a Ruby older than 4.0, `require "stryker/runtime"` writes one line to standard error that names the Ruby version and links to this page.

This page lists the problems found so far on Ruby 3.3 and 3.4. The project doesn't search for more on those versions. When you find one, [open an issue](https://github.com/setdef/stryker_for_ruby/issues), and it goes on this page.

| Problem | Ruby 3.3 | Ruby 3.4 |
| - | - | - |
| [A hit from a non-main Ractor can't be recorded](#a-hit-from-a-non-main-ractor-cant-be-recorded) | yes | yes |
| [A fork while a Ractor is running crashes the child](#a-fork-while-a-ractor-is-running-crashes-the-child) | yes | no |
| [`require` in a non-main Ractor raises](#require-in-a-non-main-ractor-raises) | yes | no |
| [`ERB.new` raises in a non-main Ractor](#erbnew-raises-in-a-non-main-ractor) | yes | yes |
| [Stdlib ERB's constructor has other parameters](#stdlib-erbs-constructor-has-other-parameters) | yes | no |
| [A private index method called through `self` in a multiple assignment](#a-private-index-method-called-through-self-in-a-multiple-assignment) | yes | no |

## A hit from a non-main Ractor can't be recorded

**Ruby 3.3 and 3.4.** The dry run records a hit from code that runs in a Ractor other than the main one by sending it to a collector Ractor, through a `Ractor::Port`. Ruby 3.3 and 3.4 have no `Ractor::Port`, and a send from a thread inside a non-main Ractor hangs there, so no mechanism records such a hit.

A switch that runs in a non-main Ractor in the dry run raises `Stryker::UnsupportedError`. The test that ran the switch fails, so the dry run fails and no mutant runs. [Coverage](design/coverage.md#ractors) has the design.

## A fork while a Ractor is running crashes the child

**Ruby 3.3.** A process that forks while one of its Ractors is running gets a child that crashes with a segmentation fault, on macOS and on Linux. On Ruby 3.4 and later the child works. The run doesn't check for a live Ractor before it forks.

## `require` in a non-main Ractor raises

**Ruby 3.3.** `require` in a non-main Ractor raises inside RubyGems, with or without **Stryker (for Ruby)**. On Ruby 3.4 and later it runs in the main Ractor, so the loader's hook serves the instrumented source there. `load` in a non-main Ractor calls the hook in that Ractor on every version.

## `ERB.new` raises in a non-main Ractor

**Ruby 3.3 and 3.4.** `ERB.new` raises `Ractor::IsolationError` in a non-main Ractor, before any prepend of **Stryker (for Ruby)** runs, because of `ERB::NOT_GIVEN`. A template that a project compiles with stdlib ERB in a non-main Ractor fails with or without **Stryker (for Ruby)**. On Ruby 4.0 and later it works, and Erubi works in a non-main Ractor on every version.

## Stdlib ERB's constructor has other parameters

**Ruby 3.3.** Ruby 3.3 ships ERB 4.0.3, whose `ERB#initialize` takes `safe_level`, `legacy_trim_mode`, and `legacy_eoutvar` besides the parameters of ERB 6.0, which Ruby 3.4 and later ship. The ERB prepend is written for the 6.0 list only. Where a method's parameters match no list a prepend is written for, the runtime leaves that library unpatched and the dry run reports it by name and version, so a template that stdlib ERB renders on Ruby 3.3 loads uninstrumented. [ERB templates](design/erb.md#the-prepends-declare-the-exact-parameter-lists) has the rule.

## A private index method called through `self` in a multiple assignment

**Ruby 3.3.** In `self[:k], y = 2, 3`, where `[]=` is private, Ruby 3.3 calls the method through `self`, and Ruby 3.4 and later raise `NoMethodError`. Ruby calls a private method through a receiver only when the receiver is the keyword `self`, so the instrumenter never wraps a `self` receiver in a switch ([Mutant placement](design/mutant-placement.md#kinds-of-site)). A mutant that replaces that `self` with another receiver changes what the program prints on Ruby 3.3 only.
