# Mutant placement

This page specifies how the instrumenter turns a project file into instrumented source: where it puts each mutant's switch, what form the switch takes, and where the text of each mutant comes from. It covers the text edit a mutator returns, splicing into the original bytes, the switch, the rule that keeps every line where it was, the rule that moves a switch out of a site that can't hold one, the sites that get no mutant, the mutants that aren't valid Ruby, and the kinds of site that a probe tried on Ruby 3.3, 3.4, 4.0, and 4.1-dev. The reasons for compiling every mutant into the code once and switching it on at run time are in [ADR 0001](../decisions/0001-mutants-are-compiled-into-the-code-once-and-switched-on-at-run-time.md). The terms are defined in [Loading and isolation](loading-and-isolation.md#terms).

## The text edit

A mutator returns each mutant as a text edit on the original source: a byte range and the text that replaces it. The report shows exactly that edit, as the mutant's `location` and `replacement` in the [mutation testing report schema](https://github.com/stryker-mutator/mutation-testing-elements/tree/master/packages/report-schema). The other Stryker tools report their mutants the same way.

A switch wraps one node's source range. That node is usually the mutant's site, the node the mutant changes, and it is an enclosing node when the site can't hold a switch (see [Sites that can't hold a switch](#sites-that-cant-hold-a-switch)). Either way, the mutant's text is the wrapped node's original source with the edit applied.

### A heredoc opener's edit

A heredoc's body lies on the lines below its opener, outside the range of the opener and of every node around it. A mutant that replaces a heredoc opener, or removes a statement that holds one, is the opener's edit plus the removal of the heredoc's body. The body would stay in the file as code, where the plain mutant has no opener to read it. The report shows only the opener's edit, as the mutant's `location` and `replacement`.

With the edit `<<EOS` to `'z'` on this file, the plain mutant is the second one, and the first is not:

```text
# Original:
s = <<EOS
hi
EOS
p s
# Not the plain mutant: the body, `hi` and `EOS`, is code.
s = 'z'
hi
EOS
p s
# The plain mutant:
s = 'z'
p s
```

Two cases leave the body in place. A body that the edit's range already holds goes with the edit. A replacement that holds `<<` writes an opener of its own, and that opener reads the body, as when `f(<<~A, 2)` becomes `f(<<~A, 3)`. When several heredocs open on one line, their bodies follow one after the other, and the edit removes only the bodies of the openers it replaces.

The plain mutant that this page names is always the original file with the mutant's edit made and these bodies removed. The instrumented file keeps every body, under the original branch of the switch.

### An edit inside a heredoc's body

An edit inside a heredoc's body lies outside the range of the heredoc's opener and of every node around the opener. A node holds such an edit when its range holds the heredoc's opener, so the switch goes on the heredoc's node, the `StringNode` or `InterpolatedStringNode` whose range is the opener, unless a node inside the heredoc's interpolation holds the edit. The mutant's text is that node with the edit made in its body, which refract writes as a string literal on one line (see [The mutant adds no line break](#the-mutant-adds-no-line-break)), and the original branch keeps the opener, which reads the body below:

```text
# Original:
s = <<~EOS
  hello
EOS
# Instrumented, with mutant 1 replacing `hello` by `hellx`:
s = (::Stryker::Active.id == 1 ? ("hellx\n") : (::Stryker::Active.hit(1); (<<~EOS)))
  hello
EOS
```

## Splicing into the original bytes

Prism parses the file, and the instrumenter splices each switch into the original bytes around the node it wraps, on the lines that node already occupies. Everything outside the switches stays as it was, byte for byte: comments, heredocs, magic comments such as `# frozen_string_literal: true`, and the data after `__END__`.

When one switch's node encloses another's, the outer switch's original branch holds the inner switch, and each of its mutant branches holds that mutant's text with no switch inside it. A mutant branch needs no inner switch, because only one mutant is active at a time. With mutant 7 replacing `+` by `-`, and mutant 8 replacing `*` by `/`:

```text
# Original:
total = a + b * c
# Instrumented:
total = (::Stryker::Active.id == 7 ? (a - b * c) : (::Stryker::Active.hit(7); (a + (::Stryker::Active.id == 8 ? (b / c) : (::Stryker::Active.hit(8); (b * c))))))
```

Copying the inner switches into every mutant branch would multiply the output. In a probe ([#7](https://github.com/setdef/stryker_for_ruby/issues/7)), that turned the 95 KB of the standard library's `resolv.rb` into 730 KB, where mutant branches without inner switches gave 124 KB.

## The switch

With no mutant active, it runs the original code. With one of its mutants active, it runs that mutant's text instead. The switch chooses by reading `::Stryker::Active.id`, an attribute reader on an object that a constant holds, and it records a hit for [coverage](coverage.md) each time its original branch runs.

For a site with one mutant, the switch is a ternary. With mutant 7 replacing `a + b` by `a - b`:

```text
# Original:
total = a + b
# Instrumented:
total = (::Stryker::Active.id == 7 ? (a - b) : (::Stryker::Active.hit(7); (a + b)))
```

For a site with several mutants, the switch is an `if`/`elsif` chain on one line:

```text
# Original:
total = a + b
# Instrumented, with mutants 7, 8, and 9 at the site:
total = (if ::Stryker::Active.id == 7 then (a - b) elsif ::Stryker::Active.id == 8 then (a * b) elsif ::Stryker::Active.id == 9 then (0) else (::Stryker::Active.hit(7, 8, 9); (a + b)) end)
```

Every branch is in parentheses, and so is the whole switch, so the switch reads as one expression wherever the original did.

## Every line stays where it was

Instrumented source keeps every line of the original on the line where it was. That keeps `__LINE__`, `caller_locations`, `Method#source_location`, the line numbers in backtraces, and heredocs working. Two rules keep the lines in place.

### The switch adds no line break

Everything a switch puts around the original code sits on the lines the original already occupies.

```text
# Wrong: a switch across several lines moves every line after it.
x = (::Stryker::Active.id == 1 ?
  (2) :
  (1)
)
x
p __LINE__ # Prints 6, where the original, `x = 1`, `x`, and this line, printed 3.
```

A heredoc's body starts on the line after its opener, so a switch around a heredoc opener works only on one line. In the wrong form, the switch's line breaks end up inside the heredoc's body, and the file doesn't parse.

### The mutant adds no line break

A mutant's text goes into its branch on one line. A node that spans several lines keeps its original lines in the original branch, so a mutant branch whose text kept its line breaks would add lines, and every later line would move down. In the probe in [#7](https://github.com/setdef/stryker_for_ruby/issues/7), splicing matched the original in 15 of 18 line checks, and each of the other 3 failed for that reason.

The instrumenter puts each mutant's text on one line:

- When the mutant's text fits on one line, it goes into the switch as it is, unless it holds a heredoc opener. A heredoc opener in a mutant branch would read the body on the lines below the switch, which the original branch's opener reads. So when the edit leaves a heredoc opener of the wrapped node in place, or its replacement holds `<<`, the mutant's text takes the next path, where refract writes each heredoc as a string literal. So does the text of an edit inside a heredoc's body, which lies outside the wrapped node's range (see [An edit inside a heredoc's body](#an-edit-inside-a-heredocs-body)).
- Otherwise, the instrumenter makes the plain mutant, which is the whole file with the edit applied and the bodies of any replaced heredoc openers removed (see [A heredoc opener's edit](#a-heredoc-openers-edit)), parses it with Prism, converts the node at the edited range with `Refract::Converter` from the [refract](https://github.com/yippee-fun/refract) gem, formats it with `Refract::Formatter`, and joins the formatted text onto one line. Each line break that ends a statement becomes `; `, and every other line break, and one before a closing bracket, becomes a space. The joined line counts only when Prism parses it as one statement that refract formats exactly as it formatted the node.
- When the mutant's text has no one-line form, the site gets no mutant. The run reports how many sites it skipped this way, and why. The same holds when the plain mutant parses but has no one node at the edited range, so that there is no text to put on one line, as when `if c` becomes `if c then 5 end; if c`. Such a mutant is a shape the instrumenter can't place, not a fault in **Stryker (for Ruby)**, so it gets no switch and raises nothing.

Prism and refract load only in the process that instruments, never in a process that loads the project's code ([Loading and isolation](loading-and-isolation.md#two-kinds-of-process)).

## Sites that can't hold a switch

Some nodes can't be wrapped in parentheses where they stand, or change meaning when they are. When a mutant's site is one of them, the instrumenter puts the switch on the nearest enclosing node that can hold one, as StrykerJS's mutant placers do, and the mutant's text there is the enclosing node's source with the mutant's edit applied.

Only a node of a kind that a row of [Kinds of site](#kinds-of-site) names as holding a switch can hold one, and only where no row says it can't. The switch moves outward from a node of any other kind. A row whose node is "the expression's node" or "the statement's node" holds a switch only when that node is of a kind some row names. Allowing a kind by mistake gives code that parses and means something else, with no error, where leaving a kind out only gives a coarser switch, further out. So the instrumenter allows only the kinds the tables name, and the switch moves outward from a kind that a later Prism adds until a row names it.

A switch that moves out to a `def`, to a statement in a class body, or to a constant's assignment runs while the file loads, so its mutants become static mutants (see [Loading and isolation](loading-and-isolation.md#static-mutants-on-every-system)).

Adjacent string literals joined by a backslash at the end of a line, such as `"a" \` with `"b"` on the next line, can't hold a switch around one part: a switch there gives text that doesn't parse. Prism parses them as one `InterpolatedStringNode` whose parts are `StringNode`s, and a mutant of either part takes its switch on that enclosing `InterpolatedStringNode`. The standard library's `unicode_normalize/tables.rb` has strings written this way.

Three constructs mean what they mean only where they stand in a condition: a regexp literal, which Ruby matches against `$_`, a flip-flop, and an integer literal as a flip-flop's endpoint, which Ruby compares with `$.`. Prism makes the first a `MatchLastLineNode` or an `InterpolatedMatchLastLineNode`, and the second a `FlipFlopNode`. A switch would move such a construct into one of its branches, out of the condition, so no node that holds one can hold a switch: neither the construct itself nor a `!`, `not`, `&&`, `||`, `and`, `or`, pair of parentheses, or `begin ... end` around it. The switch goes on the whole conditional, such as the `if`, the `unless`, the `while`, or the ternary, where the construct stays in the condition of each branch. In `p :y if !/foo/`, a mutant of `/foo/` takes its switch on the `if`.

When no enclosing node can hold a switch, the site gets no mutant. That is the case for code inside `BEGIN { }`, which Ruby allows only at the top level of a file. It is also the case for a class or module name, and for a statement of a kind the tables don't name, such as `@count = 0` or a `for` loop, at the top level of a file or directly in a class or module body, since neither a `ClassNode` nor a `ModuleNode` holds a switch.

## Sites that get no mutant

The mutators make no mutant in the arguments of a call to `require`, `require_relative`, or `load` with no receiver. Ruby evaluates those arguments while the file loads, so every such mutant would be static, and a changed path makes Ruby load another file or raise `LoadError`, which shows nothing about the project's tests. StrykerJS's string-literal mutator skips the argument of `require()` in the same way.

A site whose mutant's text has no one-line form gets no mutant either, as [The mutant adds no line break](#the-mutant-adds-no-line-break) says.

## Mutants that aren't valid Ruby

A mutator's replacement can make a file that doesn't parse. The instrumenter parses each mutant's plain mutant, with the syntax of the running Ruby, and a mutant whose plain mutant doesn't parse gets no switch. The result lists it as skipped, with the reason `:does_not_parse`, and the run reports it with the [report schema](https://github.com/stryker-mutator/mutation-testing-elements/tree/master/packages/report-schema)'s status `CompileError`, for a mutant that is invalid.

Every parse on this page uses the syntax of the running Ruby, the Ruby that runs the project's code. When the installed Prism doesn't know that Ruby's syntax, the instrumenter raises `Stryker::Instrumenter::Error` with a message that names both versions. Prism 1.7 is the first release that knows Ruby 4.0 and 4.1.

A fault in the instrumenter is a different case. When every plain mutant parses and the instrumented file doesn't, the instrumenter raises `Stryker::Instrumenter::Error` and the run stops. A replacement that ends with a comment is such a case: `1 # why` makes a plain mutant that parses, and a switch that doesn't, because the comment swallows the rest of the line.

## Kinds of site

The probe in [#7](https://github.com/setdef/stryker_for_ruby/issues/7), and the instrumenter's site tests after it, wrapped each kind of site below in a single-line switch, ran it with no mutant active and compared the output with the original's, and then ran it with each mutant active and compared the output with the plain mutant's: the original file with only that change made, and the bodies of replaced heredoc openers removed. "Holds a switch" means both matched on Ruby 3.3, 3.4, 4.0, and 4.1-dev. The results were the same on all four versions. The Prism node is the node whose source range the switch wrapped, and each site test checks that its switch wraps a node of that kind.

Only the node kinds that the rows with "yes" name, and the kinds that the rows with "no" name as where the switch goes, hold a switch (see [Sites that can't hold a switch](#sites-that-cant-hold-a-switch)).

### Operators

| Site | Example mutant | Prism node | Holds a switch |
| - | - | - | - |
| Binary operator (`+`, `<`, `!~`) | `a + b` to `a - b` | `CallNode` | yes |
| Binary operator as a command argument with an operator after it | `puts a * b + 1`, `a * b` to `a / b` | `CallNode` | yes |
| `&&`, `\|\|`, `and`, `or` | `a && b` to `a \|\| b` | `AndNode`, `OrNode` | yes |
| Unary `-`, `~`, `!`, `not` | `-a` to `+a` | `CallNode` | yes |
| Unary minus on a power | `-a ** 2` to `a ** 2` | `CallNode` | yes |
| Negative integer literal | `-1` to `1` | `IntegerNode` | yes |

### Literals

| Site | Example mutant | Prism node | Holds a switch |
| - | - | - | - |
| String, with `frozen_string_literal: true`, `false`, or no magic comment | `'a'` to `'b'` | `StringNode` | yes; frozenness and deduplication are unchanged |
| String as a hash key | `{ 'a' => 1 }` | `StringNode` | yes |
| Interpolated string, adjacent literals, `?a` | `"a#{x}b"` to `'c'` | `InterpolatedStringNode`, `StringNode` | yes |
| Variable interpolated without braces, as in `"#@x"` or `"#$x"` | `@x` to `@y` | `InstanceVariableReadNode`, `GlobalVariableReadNode` | no: the switch goes on the string |
| Expression inside an interpolation | `"a#{x + 1}b"` | the expression's node | yes |
| `%w[]` array | `%w[a b]` to `%w[c]` | `ArrayNode` | yes |
| A word of `%w[]` or `%i[]` | `%w[a b]`, `a` to `c` | `StringNode`, `SymbolNode` | no: the switch goes on the array |
| Heredoc opener: `<<EOS`, `<<~EOS`, `<<~'EOS'`, with a method call after it, or as an argument with more arguments after it | `<<~EOS` to `'z'` | `StringNode`, `InterpolatedStringNode`, `XStringNode`, `CallNode` | yes, on one line only |
| A node whose range spans a heredoc's body | `f(<<~A, 2)` to `nil` | `CallNode` | yes |
| A line of a heredoc's body, also in a method or in the second of two heredocs on one line | `hello` to `hellx` | `StringNode`, `InterpolatedStringNode` | yes: the switch goes on the heredoc's opener, and the mutant's text is a string literal |
| Expression inside a heredoc's interpolation | `#{x + 1}` | the expression's node | yes |
| Symbol, interpolated symbol, `&:sym` | `:a` to `:b` | `SymbolNode`, `InterpolatedSymbolNode` | yes |
| Label key in a hash | `{ a: 1 }`, `a:` to `b:` | `SymbolNode` | no: the switch goes on the hash |
| Integer, float, rational, imaginary | `1` to `2` | `IntegerNode`, `FloatNode`, `RationalNode`, `ImaginaryNode` | yes |
| Integer as a receiver | `3.times` | `IntegerNode` | yes |
| Array, hash | `[1, 2]` to `[]` | `ArrayNode`, `HashNode` | yes |
| Expression under a splat | `[*a, 3]`, `a` to `[]` | the expression's node, such as `LocalVariableReadNode` | yes |
| The splat itself | `[*a, 3]`, `*a` to `0` | `SplatNode` | no: the switch goes on the array |
| Hash value, keyword-argument value | `{ a: 1 }`, `1` to `2` | the value's node | yes |
| A hash pair, or a call's keyword arguments | `a: 1` to `b: 2` | `AssocNode` | no: the switch goes on the hash or the call |
| Range, endless range | `1..3` to `1...3` | `RangeNode` | yes |
| Regexp, interpolated regexp, `/o` regexp | `/a/` to `/b/` | `RegularExpressionNode`, `InterpolatedRegularExpressionNode` | yes |
| Regexp with a capture read through `$1` | `/(b)/` to `/(c)/` | `RegularExpressionNode` | yes |
| Regexp with named captures, on the left of `=~` | `/(?<x>\d+)/` to `/(?<y>\d+)/` | `RegularExpressionNode` | no: the switch goes on the whole `=~`, a `MatchWriteNode` |

### Reads and keywords

| Site | Example mutant | Prism node | Holds a switch |
| - | - | - | - |
| Constant | `p X`, `X` to `Y` | `ConstantReadNode` | yes |
| Constant path | `A::X` to `A::Y` | `ConstantPathNode` | yes |
| The parent of a constant path, or a superclass | `A::X`, `A` to `B` | `ConstantReadNode` | yes |
| The constant path an assignment writes to | `A::B = 1`, `A::B` to `A::C` | `ConstantPathNode` | no: it can't stand in parentheses there, so the switch goes on the nearest enclosing node that holds one |
| Instance, class, or global variable | `@x` to `@y` | `InstanceVariableReadNode`, `ClassVariableReadNode`, `GlobalVariableReadNode` | yes |
| A global's name in `alias` | `alias $y $x`, `$x` to `$z` | `GlobalVariableReadNode` | no: the switch goes on the `alias`, an `AliasGlobalVariableNode` |
| `self` | `p self`, `self` to `1` | `SelfNode` | yes |
| `self` as the receiver of a call, an index, or an assignment to either | `self.x = 1`, `self` to `C.new` | `SelfNode` | no: Ruby calls a private method through a receiver only when the receiver is the keyword `self`, so the switch goes on the nearest enclosing node that holds one, such as the call |
| `nil`, `true`, `false` | `true` to `false` | `NilNode`, `TrueNode`, `FalseNode` | yes |
| Parentheses | `(1 + 2)` to `(1 - 2)` | `ParenthesesNode` | yes |

### Conditions and loops

| Site | Example mutant | Prism node | Holds a switch |
| - | - | - | - |
| Condition of `if`, `unless`, `elsif`, `while`, `until`, a ternary, or a modifier | `a > 1` to `a <= 1` | the condition's node | yes |
| Regexp literal as a condition, bare or under `!`, `not`, `&&`, `\|\|`, `and`, `or`, parentheses, or `begin ... end`, as in `if /foo/` or `if !/foo/` | `/foo/` to `/bar/` | `MatchLastLineNode`, `InterpolatedMatchLastLineNode` | no: inside a switch, Ruby reads it as a `Regexp`, which is always true, and not as a match against `$_`, so the switch goes on the whole conditional, such as the `if` |
| `!`, `not`, `&&`, `\|\|`, `and`, `or`, parentheses, or `begin ... end` in a condition, around a regexp literal or a flip-flop | `!/foo/` to `/foo/` | `CallNode`, `AndNode`, `OrNode`, `ParenthesesNode`, `BeginNode` | no: in a switch, the regexp literal or the flip-flop no longer stands in the condition, so the switch goes on the whole conditional |
| Whole ternary | `a > 1 ? :y : :n` to `:z` | `IfNode` | yes |
| Whole `unless`, also as a modifier | `unless` to `if` | `UnlessNode` | yes |
| Whole `case`/`when` | `else p :other` to `else p :another` | `CaseNode` | yes |
| Whole `elsif` | `elsif a > 1 ... end` to `elsif a > 0 ... end` | `IfNode` | no: an `elsif` in parentheses doesn't parse, so the switch goes on the whole `if` |
| Body of a `begin ... end while` or `begin ... end until` loop | `begin ... end` to `nil` | `BeginNode` | no: Ruby runs the body of `begin ... end while` once before it tests the condition, but a wrapped `begin ... end` makes an ordinary modifier loop, which tests first, so the switch goes on the whole loop, a `WhileNode` or `UntilNode` |
| A statement inside a `begin ... end while` loop | `i += 1` to `nil` | the statement's node | yes |
| `begin ... end`, also with `rescue` or `ensure` | `begin ... end` to `2` | `BeginNode` | yes |
| A body with `rescue` or `ensure` and no `begin` keyword, as in a `def` or a `do ... end` block | `rescue ... :rescued` to `rescue ... :saved` | `BeginNode` | no: it can't stand in parentheses, so the switch goes on the nearest enclosing node that holds one, such as the `def` or the call that takes the block |
| `case`/`when`: value, subject, splat's expression, condition without a subject, body statement | `when 1` to `when 2` | the node | yes |
| `case`/`in` pattern | `in Integer` to `in String` | the pattern's node | no: the switch goes on the whole `case`/`in` |
| Whole `case`/`in` | the `case` with another pattern | `CaseMatchNode` | yes |
| `case`/`in`: pinned expression, guard, body statement | `^(2 + 3)` to `^(9)` | the node | yes |
| `x in pattern`, `x => pattern` | `x in Integer` to `x in String` | `MatchPredicateNode`, `MatchRequiredNode` | yes |
| Flip-flop, whole, also under `!`, `not`, `&&`, `\|\|`, `and`, `or`, parentheses, or `begin ... end` | `(i == 2)..(i == 4)` to `false` | `FlipFlopNode` | no: inside a switch, Ruby reads it as a `Range` and raises `ArgumentError`, so the switch goes on the whole conditional, such as the `if` |
| Flip-flop endpoint | `i == 2` to `i == 3` | the endpoint's node | yes |
| Integer literal as a flip-flop endpoint, as in `if 2..4` | `2` to `3` | `IntegerNode` | no: Ruby compares an integer endpoint with `$.` only while it is a literal there, so the switch goes on the whole conditional |

### Calls

| Site | Example mutant | Prism node | Holds a switch |
| - | - | - | - |
| Argument | `f(3)` to `f(4)` | the argument's node | yes |
| Call removed, as a value or a statement | `f` to `nil` | `CallNode` | yes |
| Call replaced by its receiver | `s.upcase` to `s` | `CallNode` | yes |
| Call with a `{ }` block, with a `do ... end` block, or as a command call's argument before `do` | `[1, 2].map { ... }` to `[]` | `CallNode` | yes |
| Safe navigation: read, chain, assignment, operator assignment, and an assignment's right side | `a&.length` to `a.length` | `CallNode`, `CallOperatorWriteNode` | yes |
| Index call, attribute assignment | `a[0]` to `a[1]` | `CallNode` | yes |
| Lambda literal | `->(x) { x }` to `->(x) { 0 }` | `LambdaNode` | yes |
| `yield`, with or without arguments, and its removal | `yield(1)` to `yield(2)` | `YieldNode` | yes |
| `super` with arguments | `super(a)` to `super(a + 1)` | `SuperNode` | yes |
| Bare `super`, which forwards arguments, keyword arguments, and the block | `super` to `0` | `ForwardingSuperNode` | yes |
| `__method__`, also through an alias | `__method__` to `:z` | `CallNode` | yes |
| `__LINE__`, `__FILE__`, `__dir__` | `__LINE__` to `0` | `SourceLineNode`, `SourceFileNode`, `CallNode` | yes, with a single-line switch |

### Statements and definitions

| Site | Example mutant | Prism node | Holds a switch |
| - | - | - | - |
| A statement removed, in a method or a block, including the last one | `puts 'b'` to `nil` | the statement's node, such as `CallNode` or `LocalVariableWriteNode` | yes |
| `return`, `next`, `break`, `redo`, `retry`, as a statement, as an operand, or as the last statement | `return 1` to `return 2` | `ReturnNode`, `NextNode`, `BreakNode`, `RedoNode`, `RetryNode` | yes |
| A returned value | `return 1` to `return 2`, on `1` | the value's node | yes |
| Expression inside `defined?` | `defined?(foo)` to `defined?(bar)` | the expression's node | no: `defined?` of a switch always gives `"expression"`, so the switch goes on the whole `defined?` |
| Whole `defined?`, also `defined?(yield)` | `defined?(foo)` to `nil` | `DefinedNode` | yes |
| `BEGIN { }` | removed | `PreExecutionNode` | no: Ruby allows `BEGIN` only at the top level, so no switch can hold it, and the site gets no mutant |
| `END { }` | removed | `PostExecutionNode` | yes |
| `alias`, `alias` of a global, `undef` | removed | `AliasMethodNode`, `AliasGlobalVariableNode`, `UndefNode` | yes |
| A name in `alias` or `undef` | `alias z x`, `x` to `y` | `SymbolNode` | no: the switch goes on the `alias` or `undef` |
| Class or module name | `class Foo` to `class Bar` | `ConstantReadNode`, `ConstantPathNode` | no: neither the name nor the `ClassNode` or `ModuleNode` holds a switch, so the switch goes on the nearest enclosing node that holds one, and the site gets no mutant when no node around it holds one, as at the top level of a file or inside a module |
| Method name in a `def` | `def foo` to `def bar` | none: the name is a location, not a node | no: the switch goes on the whole `def` |
| Whole `def`, endless or not: renamed, removed, or changed | `def foo = 1` to `def bar = 1` | `DefNode` | yes; the mutant is static |
| Endless method body, a value or a command | `def f(x) = x + 1`, `x + 1` to `x - 1` | the body's node | yes |
| `private def`: the `def` as the argument, the body, or the whole call | `private def foo = 1` to `nil` | `DefNode`, `CallNode` | yes |
| Bare `private`, or a `def` after it | `private` to `nil` | `CallNode`, `DefNode` | yes |
| A constant's value, in a file or a class body, also with `\|\|=` | `X = 1` to `X = 2` | the value's node | yes; the mutant is static |
| A whole constant assignment | `X = 1` to `nil` | `ConstantWriteNode` | yes; the mutant is static |
| A call in a class body | `attr_reader :a` to `nil` | `CallNode` | yes; the mutant is static |

### Assignment

| Site | Example mutant | Prism node | Holds a switch |
| - | - | - | - |
| One value on the right of a multiple assignment | `a, b = 1, 3`, `1` to `2` | the value's node | yes |
| The whole bare right side of a multiple assignment | `a, b = 1, 2`, `1, 2` to `2, 1` | `ArrayNode` | no: the switch goes on the whole assignment |
| A whole multiple assignment | `a, b = b, a` to `a, b = a, b` | `MultiWriteNode` | yes |
| The right side of `\|\|=`, `+=` | `a \|\|= 1` to `a \|\|= 2` | the value's node | yes |
| A whole `\|\|=`, `+=`, `&&=`, `h[k] \|\|=` | `a += 1` to `a -= 1` | `LocalVariableOrWriteNode`, `LocalVariableOperatorWriteNode`, `LocalVariableAndWriteNode`, `IndexOrWriteNode` | yes |
| Code in a file that ends with `__END__` | `1` to `2` | the node | yes; `DATA` is unchanged |

### Parameters

| Site | Example mutant | Prism node | Holds a switch |
| - | - | - | - |
| Default value of a positional, keyword, block, or lambda parameter, also one that refers to an earlier parameter | `def f(a = 1)`, `1` to `2` | the value's node | yes |
| Removing a default | `def f(a = 1)` to `def f(a)` | `OptionalParameterNode` | no: the switch goes on the whole `def` |

### Several mutants at one site

| Site | Example mutants | Prism node | Holds a switch |
| - | - | - | - |
| An operator with three mutants | `a + b` to `a - b`, `a * b`, `0` | `CallNode` | yes, as an `if`/`elsif` chain |
| A condition with four mutants | `a > 1` to `true`, `false`, `a < 1` | `CallNode` | yes |

## Traps at sites that hold a switch

- **Named captures stay declared.** A match such as `/(?<x>\d+)/ =~ s` declares the local `x` when Ruby parses it. With the switch on the whole match and its mutant active, the match doesn't run, but `x` is still declared, as `nil`. The plain mutant has no `x` at all, so `defined?(x)` gives `"local-variable"` under the switch and `nil` in the plain mutant, and a later read of `x` gives `nil` where the plain mutant raises `NameError`.
- **A local declared under a switch stays declared.** Removing a statement such as `x = 1` leaves `x` declared under the switch, as a named capture does: Ruby declares a local when it parses the assignment, and the mutant's branch has no assignment, so `x` is `nil`. With `x = 1` followed by `p x`, and the statement removed, the switched form prints `nil`, where the plain mutant raises `NameError`. A later read of `x` gives `nil` and not an error.
- **A regexp literal in a condition warns twice.** Ruby warns `regex literal in condition` for each regexp literal it finds in a condition, and a switch on `p :y if /foo/` holds two of them, one in each branch. The switched form writes the warning twice to standard error, where the original and the plain mutant write it once. What the program prints to standard output is the same.
- **A mutant that is invalid without a switch stays invalid.** Removing a default from `def f(a = 1)` makes every call `f()` raise `ArgumentError`, and so does the switched form. The switch reproduces the plain mutant; it doesn't make a broken mutant work.

## What this design doesn't do

- It doesn't place a mutant inside `BEGIN { }`.
- It doesn't mutate the path given to `require`, `require_relative`, or `load`.
- It doesn't keep a site's mutant runtime when its switch has to move out to a definition or to a statement in a class body: such a mutant is static.
- It doesn't make a mutant whose text has no one-line form. The run counts such sites instead.
- It doesn't make a mutant whose plain mutant doesn't parse. The run reports such a mutant as `CompileError`.
- It doesn't keep the original layout inside a mutant's text when the wrapped node spans several lines: the instrumenter formats that text with refract.
