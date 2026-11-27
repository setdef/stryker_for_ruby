# Mutators

This page specifies which mutants **Stryker (for Ruby)** makes. It covers the catalog of mutators and the exact pairs each one makes, the mutators that run when nothing is configured, the sites that get no mutant, and the equivalent mutants the mutators avoid. Where each mutant's switch goes is in [Mutant placement](mutant-placement.md), and the terms are defined in [Loading and isolation](loading-and-isolation.md#terms).

Every rule here serves one aim: each mutant that survives should be worth acting on. A survivor shows that no test would catch a mistake at its site, and its reader then writes a test, strengthens one, or removes the code. People who meet survivors they can't act on learn to ignore the report, so the catalog leaves out pairs whose survivors would show nothing.

## Terms

- **Mutator:** the part of the instrumenter that finds one kind of site and makes its mutants.
- **Mutator name:** the name in the report's `mutatorName` field, and that `mutator.excludedMutations` accepts.
- **Pair:** an original construct and the mutant a mutator makes from it, such as `a < b` and `a <= b`.
- **Edit:** the byte range a mutant changes and the text that replaces it ([The text edit](mutant-placement.md#the-text-edit)).

## Names

Each Stryker tool reports the same names, so a report from **Stryker (for Ruby)** reads like one from StrykerJS and the Stryker dashboard can compare them. A mutator that does what a Stryker mutator does takes the name exactly as StrykerJS spells it in the `mutatorName` it reports, not the other spellings the sources use:

| Source | What it uses | Example | Why the catalog doesn't use it |
| - | - | - | - |
| StrykerJS's code | Group names, in `mutatorName` | `AssignmentOperator`, `BlockStatement` | It does: these are the names used here. |
| The shared [supported-mutators page](https://stryker-mutator.io/docs/mutation-testing-elements/supported-mutators/) | Group titles, and a name for each pair | "Assignment Expression", `AdditionNegation` | The titles have spaces and differ from StrykerJS's code, and no tool reports or accepts the pair names. |
| Stryker.NET | Short names in its configuration, and display names in its report | `Arithmetic`, "Arithmetic mutation" | Stryker.NET reports one name for a mutator and accepts another in its configuration. |
| Stryker4s | Group names, close to StrykerJS's | `RegularExpression` | StrykerJS's `Regex` is the spelling that the shared page and Stryker.NET also use. |

A mutator for a Ruby construct that no Stryker tool mutates follows the organization's naming rule, from the thread behind the shared page ([stryker-handbook#11](https://github.com/stryker-mutator/stryker-handbook/issues/11)): a name follows the construct, is language-neutral and singular, and ends in a category word, one of Operator, Literal, Expression, Statement, or Declaration. Every name is letters only, because StrykerJS's disable-comment grammar accepts only letters, commas, and spaces in its list of names.

Where the sources disagree on the pairs, the catalog follows StrykerJS's code, because the name in `mutatorName` is StrykerJS's: a reader who knows what StrykerJS's `EqualityOperator` makes finds the same pairs here. Each place where the catalog departs from StrykerJS's pairs gives its reason.

## The catalog

Seven mutators make up the catalog, and each has the name of a Stryker mutator. The run uses this table's order to choose which of two identical mutants it keeps (see [Mutants the mutators don't make](#mutants-the-mutators-dont-make)).

| Mutator | What it mutates | Prism nodes | Stryker counterpart |
| - | - | - | - |
| `ArithmeticOperator` | `+`, `-`, `*`, `/`, `%` between two operands | `CallNode` | StrykerJS `ArithmeticOperator` |
| `ArrayDeclaration` | Array literals and `Array.new` | `ArrayNode`, `CallNode` | StrykerJS `ArrayDeclaration` |
| `BooleanLiteral` | `true`, `false`, `!`, `not`, the negation in `unless` and `until` | `TrueNode`, `FalseNode`, `CallNode`, `UnlessNode`, `UntilNode` | StrykerJS `BooleanLiteral` |
| `EqualityOperator` | `<`, `<=`, `>`, `>=`, `==`, `!=`, and the operands of `<=>` | `CallNode` | StrykerJS `EqualityOperator` |
| `LogicalOperator` | `&&`, `\|\|`, `and`, `or` | `AndNode`, `OrNode` | StrykerJS `LogicalOperator` |
| `StringLiteral` | String literals, interpolated strings, and heredocs | `StringNode`, `InterpolatedStringNode` | StrykerJS `StringLiteral` |
| `UnaryOperator` | Unary `-`, `+`, `~`, and signed numeric literals | `CallNode`, `IntegerNode`, `FloatNode`, `RationalNode`, `ImaginaryNode` | StrykerJS `UnaryOperator` |

### How to read the tables

In each mutator's table, the **Kills it** column says what a test has to do to tell the mutant from the original. It is for the readers of this design, who judge whether a pair is worth making. Italics name a part of the original, such as *left* or *receiver*.

A mutant's edit covers the whole node the mutator changes, as StrykerJS's edits do, so the report's `replacement` reads as code by itself: `a + b` becomes `a - b`, not `-`. The exceptions are said where they apply.

### `ArithmeticOperator`

It mutates a binary operator call: a `CallNode` named `+`, `-`, `*`, `/`, or `%`, written as an operator between a receiver and one argument, with no `.` and no block.

| Original | Mutant | Kills it |
| - | - | - |
| `a + b` | `a - b` | A test that checks the result with *right* not zero. |
| `a - b` | `a + b` | A test that checks the result with *right* not zero. |
| `a * b` | `a / b` | A test that checks the result with operands whose product and quotient differ. |
| `a / b` | `a * b` | A test that checks the result with operands whose quotient and product differ. |
| `a % b` | `a * b` | A test that checks the result. |

It makes no mutant when either operand is a string literal (`StringNode`, `InterpolatedStringNode`, `XStringNode`, or `InterpolatedXStringNode`), as StrykerJS skips string operands. In Ruby, `"=" * 40`, `"%.2f" % total`, and `names * ", "` repeat, format, and join, and their mutants raise `NoMethodError` at the first test that runs them, so each is killed by any test that reaches it and shows nothing that coverage doesn't.

Ruby's `**`, `<<`, and `>>` get no mutant, as in StrykerJS. `<<` is mostly append in Ruby, and a mutant that turns an append into a shift raises at once.

### `ArrayDeclaration`

| Original | Mutant | Kills it |
| - | - | - |
| `[a, b]`, `%w[a b]`, `%i[a b]`, `[*items]` | `[]` | A test that checks the array's elements. |
| `[]` | `["Stryker was here"]` | A test that checks that the array is empty. |
| `Array.new(3, 0)` | `Array.new` | A test that checks the array's elements. |

The replacement text for an empty array is StrykerJS's. An array with no brackets, the right side of `a, b = 1, 2`, gets no mutant: `a, b = []` reads as a different assignment, not as an emptied array. StrykerJS turns `new Array()` into `new Array([])`, but in Ruby `Array.new([])` and `Array.new` both give an empty array, so `Array.new` with no arguments, or with `[]`, gets no mutant. The `[]` inside `Array.new([])` still gets its own mutant.

### `BooleanLiteral`

| Original | Mutant | Kills it |
| - | - | - |
| `true` | `false` | A test that checks the value this `true` gives. |
| `false` | `true` | A test that checks the value this `false` gives. |
| `!x`, `not x` | `x` | A test that checks the result. |
| `unless c` | `if c` | A test that checks which branch runs. |
| `until c` | `while c` | A test that checks how many times the loop runs. |

`nil` isn't a boolean literal, and no mutator makes `nil` from `false` or `false` from `nil`. Wherever the value only reaches a condition, which is the usual case, `nil` and `false` behave the same, so such a mutant would survive and show nothing. `true` becomes `false` and not `nil` for the same reason.

`unless c` is `if !c`, and `until c` is `while !c`, so turning `unless` into `if` is the same mutation as StrykerJS's removal of the `!` in `if (!c)`. An `unless` hides its negation in the keyword, which makes a compound condition such as `unless paid && shipped` easy to get backwards, and a survivor shows that no test takes the other branch. A project that turns off `BooleanLiteral` turns these off too. Because the node spans its whole body, the edit for these two covers only the keyword, and the report's `replacement` is `if` or `while`.

An `unless`, an `until`, or a negation whose condition or operand is the comparison `__FILE__ == $0` gets no mutant, as in `unless __FILE__ == $0` and `!(__FILE__ == $0)` (see [Sites that get no mutant](#sites-that-get-no-mutant)).

### `EqualityOperator`

It mutates a `CallNode` named `<`, `<=`, `>`, `>=`, `==`, `!=`, or `<=>`, written as an operator between a receiver and one argument.

| Original | Mutant | Kills it |
| - | - | - |
| `a < b` | `a <= b` | A test where *left* equals *right*. |
| `a < b` | `a >= b` | A test that checks the result. |
| `a <= b` | `a < b` | A test where *left* equals *right*. |
| `a <= b` | `a > b` | A test that checks the result. |
| `a > b` | `a >= b` | A test where *left* equals *right*. |
| `a > b` | `a <= b` | A test that checks the result. |
| `a >= b` | `a > b` | A test where *left* equals *right*. |
| `a >= b` | `a < b` | A test that checks the result. |
| `a == b` | `a != b` | A test that checks the result. |
| `a != b` | `a == b` | A test that checks the result. |
| `a <=> b` | `b <=> a` | A test that checks the order of two values that aren't equal. |

The sources disagree on these pairs. For `a > b`, StrykerJS and the shared page make `>=` and `<=`, Stryker.NET makes `>=` and `<`, and Stryker4s makes `>=`, `<`, and `==`. The catalog follows StrykerJS. Each comparison gets one boundary mutant, which only a test at the boundary kills, and that test is the one that catches an off-by-one mistake. It also gets one negation, which any test of the outcome kills, so its survivor shows that no test checks the outcome at all. Stryker.NET's `a < b` for `a > b` differs from the original in every case where the negation does, except when the two sides are equal, so it tests the boundary a second time. Stryker4s's `==` adds a third mutant to every comparison.

`===` gets no mutant: Ruby has no `!==`, and `===` is case equality, which code calls mostly through `case`/`when`. `eql?` and `equal?` are method calls and get none either.

The `<=>` row swaps the operands instead of changing the operator. Ruby orders values by `<=>`: `sort`, `Comparable`, `min`, and `max` all call it. A comparison written backwards, in a `sort` block or in a `def <=>(other)`, reverses every order built on it, and a survivor shows that no test checks the order. No Stryker tool has a counterpart, because JavaScript, C#, and Scala have no operator that returns -1, 0, or 1. The row sits under `EqualityOperator` and not in a separate mutator because the organization merged its proposed "Compare Operator" group into "Equality Operator", since the two are alike and its mutators turn one into the other ([stryker-handbook#11](https://github.com/stryker-mutator/stryker-handbook/issues/11)). It makes no mutant when the two operands have the same text, such as `x <=> x`. It makes none either when an operand holds a heredoc opener, such as `foo(<<~A) <=> bar(<<~B)`: a heredoc's body follows its opener, and the bodies follow in the order of the openers, so the swap would give each opener the other's body, or leave a body with no opener, which isn't valid Ruby.

A swapped operand that is a bare `defined?`, `not`, `and`, or `or`, or an assignment, goes in parentheses. Each binds looser than `<=>`, so `a <=> defined? b` would swap to `defined? b <=> a`, which Ruby reads as `defined?(b <=> a)`, and `a <=> x = 1` would swap to `x = 1 <=> a`, which Ruby reads as `x = (1 <=> a)`. The mutants are `(defined? b) <=> a` and `(x = 1) <=> a`. An operand that has parentheses of its own, such as `defined?(b)` or `(x = 1)`, is swapped as written.

### `LogicalOperator`

| Original | Mutant | Kills it |
| - | - | - |
| `a && b` | `a \|\| b` | A test where one side is truthy and the other falsy. |
| `a \|\| b` | `a && b` | A test where one side is truthy and the other falsy. |
| `a and b` | `a or b` | A test where one side is truthy and the other falsy. |
| `a or b` | `a and b` | A test where one side is truthy and the other falsy. |

When the last `||` of a chain such as `a || b || c` becomes `&&`, the replacement is `(a || b) && c`, with the operands before that `||` in parentheses, because `a || b && c` would group the other way. The other three pairs need no parentheses, since each gives a replacement that groups as the original does.

An operator that has the comparison `__FILE__ == $0` as an operand gets no mutant, as in `__FILE__ == $0 and main` (see [Sites that get no mutant](#sites-that-get-no-mutant)).

StrykerJS also turns `a ?? b` into `a && b`. Ruby has no `??`: `name || "Guest"` is the idiom for a default, and it takes the `||` pair.

### `StringLiteral`

| Original | Mutant | Kills it |
| - | - | - |
| `"Free shipping"`, `'Free shipping'`, `?a` | `""` | A test that checks the string. |
| `""`, `''` | `"Stryker was here!"` | A test that checks that the string is empty. |
| `"Total: #{total}"`, `"a" "b"` | `""` | A test that checks the string. |
| `<<~TEXT` | `""` | A test that checks the string. |

The replacement texts are StrykerJS's. An interpolated string, and adjacent literals joined into one, are mutated whole, as StrykerJS mutates a template literal whole. A string inside an interpolation, at any depth, or a part of `"a" "b"`, gets no separate mutant. The edit for a heredoc covers only its opener, such as `<<~TEXT`, because that is the heredoc node's range, and its body stays where it is ([Kinds of site](mutant-placement.md#literals)). A string is empty when it has no text and no interpolation, so an empty heredoc, `%q()`, and `"" ''` get the text.

It makes no mutant of:

- the key of a hash pair, such as `"rate"` in `{ "rate" => 0.1 }`, as StrykerJS doesn't mutate an object's keys;
- an element of `%w[]` or `%W[]`, whose syntax has no empty element and has no quotes to put around one;
- the pattern given to `Regexp.new`, a string without interpolation that is the first argument, which is the source of a regular expression and not text;
- a backtick or `%x` command (`XStringNode`, `InterpolatedXStringNode`), because the mutant makes the tests run a different command on the machine.

A string that Ruby freezes under `frozen_string_literal: true` is replaced by one that Ruby freezes too, so frozenness doesn't change ([Kinds of site](mutant-placement.md#literals)). An interpolated string, with or without a heredoc, isn't frozen under that comment, and `""` is, so a test that appends to such a string raises `FrozenError` with the mutant active and kills it.

### `UnaryOperator`

| Original | Mutant | Kills it |
| - | - | - |
| `-a` | `a` | A test with *operand* not zero. |
| `+a` | `-a` | A test with *operand* not zero. |
| `~a` | `a` | A test that checks the result. |
| `-1`, `-2.5`, `-1r` | `1`, `2.5`, `1r` | A test that checks the value. |
| `+1`, `+2.5`, `+1r` | `-1`, `-2.5`, `-1r` | A test that checks the value. |

StrykerJS turns `-a` into `+a`. In Ruby, `+a` calls `+@`, which `Numeric` defines but most other classes don't, so `+a` would raise `NoMethodError` for a `Vector` or a `Money` and be killed at once. `a` gives the same value as `+a` on a number and works on any receiver. A signed number literal, such as `-1` or `+1`, is an `IntegerNode`, `FloatNode`, `RationalNode`, or `ImaginaryNode` in Prism, not a call, and it gets the same mutant as `-a` or `+a`, as StrykerJS mutates `-1` and `+1`.

A zero of any kind (`-0`, `-0.0`, `-0r`, `-0i`, and the same with `+`) gets no mutant. An integer, rational, or imaginary zero equals the zero without its sign, so that mutant would be equivalent. A float zero doesn't: `1 / -0.0` is `-Infinity` and `1 / 0.0` is `Infinity`. Only a test that divides by the value tells the two apart, so the survivor of that mutant wouldn't be worth acting on, and the rule applies to `-0.0` all the same.

It makes no mutant of `-` or `+` on a string literal, such as `-"draft"`: those control whether the string is frozen (see [Sites that get no mutant](#sites-that-get-no-mutant)).

## Constructs that get no mutator

Each of these was left out of the catalog because its survivors would rarely be worth acting on:

| Construct | Why no mutator makes a mutant of it |
| - | - |
| `nil` | `nil` and `false` behave the same in a condition, and any other replacement raises at once. |
| Symbols, `&:sym` | A symbol is the name of a method, key, or option, and a symbol nobody defines raises `NoMethodError`, `KeyError`, or `ArgumentError` at the first test that reaches it, which shows nothing that coverage doesn't. |
| Number literals | No Stryker tool mutates them. The boundary mutants of `EqualityOperator` test the values where off-by-one mistakes matter. |
| `case`/`in` patterns, flip-flops, `defined?`, `yield`, `super` | No Stryker tool has a counterpart, and their mutants mostly raise or change nothing a test sees. Their bodies and guards still get mutants. |

## Defaults

Every mutator in the catalog runs when nothing is configured, as every StrykerJS and Stryker4s mutator does. The catalog leaves out the pairs whose survivors wouldn't be worth acting on, so there is no second list of mutators that are off by default to learn. Stryker.NET's mutation levels, which leave some mutators off to save run time, have no counterpart: the configuration takes StrykerJS's option names ([#3](https://github.com/setdef/stryker_for_ruby/issues/3)), and StrykerJS has no levels.

### Logger calls and `# :nocov:`

No site is ignored by default. A call to a logger gets the same mutants as any other call, and code between `# :nocov:` comments, the markers that SimpleCov reads, gets its mutants too.

No other Stryker tool ignores a logging call by default. StrykerJS ships only an `angular` ignorer, and a maintainer wrote in [stryker-js#1174](https://github.com/stryker-mutator/stryker-js/issues/1174) that a log statement that no test checks shouldn't be swept under a rug. The default of Stryker.NET's `ignore-methods` is empty. Only Stryker.NET honors a coverage exclusion, `[ExcludeFromCodeCoverage]`, and StrykerJS and Stryker4s honor none.

## Sites that get no mutant

These sites get no mutant from any mutator, and no switch. The table gives each rule's reason.

| Site | Reason |
| - | - |
| A call with no receiver to `require`, `require_relative`, `load`, or `autoload`, and `autoload` called on a module: the call's arguments, and the call's removal | A changed path loads another file or raises `LoadError`, and a removed `require` or `autoload` either raises `NameError` or changes nothing because another file loaded the same code. Each such mutant is static, so it would cost a fresh process and the whole suite. [Mutant placement](mutant-placement.md#sites-that-get-no-mutant) gives the rule for the arguments. |
| A backtick or `%x` command | See [`StringLiteral`](#stringliteral). |
| Comments, magic comments such as `# frozen_string_literal: true`, and the data after `__END__` | They aren't code that Prism gives a mutator. The instrumenter keeps them byte for byte ([Splicing into the original bytes](mutant-placement.md#splicing-into-the-original-bytes)). |
| `freeze` | No mutator removes a call to `freeze`, or the `-` or `+` before a string literal. The receiver behaves the same unfrozen unless some code changes it, and only a test that expects `FrozenError` would kill the mutant, so it would survive on every frozen constant. |
| The comparison `__FILE__ == $0` or `__FILE__ == $PROGRAM_NAME`, either way round, wherever it stands | A mutant that makes the comparison true, such as `true` in its place or `!=` for `==`, runs the file's script code inside the test process, where it does whatever the script does. The comparison gets none whether it is a condition or a value. |
| A node whose condition or operand is that comparison, with any parentheses around the comparison ignored: an `if`, `unless`, `elsif`, `while`, `until`, or ternary condition, an operand of `&&`, `\|\|`, `and`, or `or`, and the operand of `!` or `not` | A mutator that changes such a node makes no mutant of it, `LogicalOperator` and `BooleanLiteral` among them, because each mutant would change whether the comparison decides, and run the file's script code inside the test process, as `true` in place of the comparison does. `__FILE__ == $0 and main`, `unless __FILE__ == $0`, and `!(__FILE__ == $0)` get none, as the bare `if __FILE__ == $0` gets none. The mutants inside such a node, in its body or in an operand that isn't the comparison, are made. |
| A call with no receiver to `sig` with a block, and everything inside the block | It is a [Sorbet](https://sorbet.org) type signature, the counterpart of the type annotations that StrykerJS never mutates. The block is out of every mutator's reach, so no mutator makes a mutant of a call, a literal, or an operator inside it. |
| Code inside `BEGIN { }`, and a mutant with no one-line form | See [Mutant placement](mutant-placement.md#sites-that-get-no-mutant). |

### Test files

The default of the `mutate` option leaves out test files ([`mutate`](../../configuration.md#mutate)), as StrykerJS's default leaves out `__tests__` directories and file names that end in `test` or `spec`. A pattern that the project writes can still match a test file, and that file then gets mutants: no check stops it, as none stops it in StrykerJS.

## Equivalent mutants

An equivalent mutant behaves the same as the original for every input, so no test can kill it, and its survivor wastes its reader's time. No Stryker tool detects equivalent mutants in general, and neither does **Stryker (for Ruby)**. The mutators avoid the ones that the source text alone proves equivalent.

### Mutants the mutators don't make

- **Identical mutants.** When two mutants give the same text for the whole file, the run keeps one: the mutant whose mutator comes first in [the catalog](#the-catalog), and between two of the same mutator, the one whose site starts first. In `!!ready`, removing either `!` gives `!ready`, and the run keeps the outer one.
- **A mutant equal to the original.** A mutant whose text for the whole file is the original's is never made, such as `x <=> x` swapped.
- **Mutants whose equivalence the syntax shows.** Each mutator's section lists them: `-0`, `-0r`, and `-0i`, and `Array.new` given no argument or `[]`.

A mutant whose equivalence depends on a value's class or range at run time is made. For example, `x > 0` and `x >= 1` agree when `x` is an `Integer`, and differ when it is `0.5`, and the instrumenter can't know which `x` holds. Leaving such a mutant out would hide every real mistake that it stands for.

## What this design doesn't do

- It doesn't detect equivalent mutants beyond the ones the source text proves.
- It doesn't use a value's class: the operator mutators match by name and syntax alone.
- It has no mutation levels: every mutator runs.
- It doesn't ignore a site by default: logger calls and code between `# :nocov:` comments get mutants.
- It doesn't mutate symbols, numbers other than their sign, `nil`, or `case`/`in` patterns.
