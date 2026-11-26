# Mutators

This page specifies which mutants **Stryker (for Ruby)** makes and how it reports each one. It covers the catalog of mutators and the exact pairs each one makes, the mutators that run when nothing is configured, the sites that get no mutant, the equivalent mutants the mutators avoid, the disable comment, the fields each mutant fills in the report, and what changes in ERB templates. Where each mutant's switch goes is in [Mutant placement](mutant-placement.md), and the terms are defined in [Loading and isolation](loading-and-isolation.md#terms).

Every rule here serves one aim: each mutant that survives should be worth acting on. A survivor shows that no test would catch a mistake at its site, and its reader then writes a test, strengthens one, or removes the code. People who meet survivors they can't act on learn to ignore the report, so the catalog leaves out pairs whose survivors would show nothing. Each mutant's `location`, `replacement`, and `coveredBy` in the report show its reader where the mutant is, what it changed, and which tests ran it.

## Terms

- **Mutator:** the part of the instrumenter that finds one kind of site and makes its mutants.
- **Mutator name:** the name in the report's `mutatorName` field, and that `mutator.excludedMutations` and the disable comment accept.
- **Pair:** an original construct and the mutant a mutator makes from it, such as `a < b` and `a <= b`.
- **Live mutant:** a mutant that isn't `Ignored`, so it gets a switch and runs.
- **Edit:** the byte range a mutant changes and the text that replaces it ([The text edit](mutant-placement.md#the-text-edit)).

## Names

Each Stryker tool reports the same names, so a report from **Stryker (for Ruby)** reads like one from StrykerJS and the Stryker dashboard can compare them. A mutator that does what a Stryker mutator does takes the name exactly as StrykerJS spells it in the `mutatorName` it reports, not the other spellings the sources use:

| Source | What it uses | Example | Why the catalog doesn't use it |
| - | - | - | - |
| StrykerJS's code | Group names, in `mutatorName` | `AssignmentOperator`, `BlockStatement` | It does: these are the names used here. |
| The shared [supported-mutators page](https://stryker-mutator.io/docs/mutation-testing-elements/supported-mutators/) | Group titles, and a name for each pair | "Assignment Expression", `AdditionNegation` | The titles have spaces and differ from StrykerJS's code, and no tool reports or accepts the pair names. |
| Stryker.NET | Short names in its configuration, and display names in its report | `Arithmetic`, "Arithmetic mutation" | Stryker.NET reports one name for a mutator and accepts another in its configuration. |
| Stryker4s | Group names, close to StrykerJS's | `RegularExpression` | StrykerJS's `Regex` is the spelling that the shared page and Stryker.NET also use. |

A mutator for a Ruby construct that no Stryker tool mutates follows the organization's naming rule, from the thread behind the shared page ([stryker-handbook#11](https://github.com/stryker-mutator/stryker-handbook/issues/11)): a name follows the construct, is language-neutral and singular, and ends in a category word, one of Operator, Literal, Expression, Statement, or Declaration. StrykerJS's `OptionalChaining` and `Regex` are the names in the catalog that end in none. `RangeOperator`, which swaps `..` and `...`, is the one name that no Stryker tool has, because no Stryker tool mutates a range. Every name is letters only, because StrykerJS's disable-comment grammar accepts only letters, commas, and spaces in its list of names.

Where the sources disagree on the pairs, the catalog follows StrykerJS's code, because the name in `mutatorName` is StrykerJS's: a reader who knows what StrykerJS's `EqualityOperator` makes finds the same pairs here. Each place where the catalog departs from StrykerJS's pairs gives its reason, and the methods that `MethodExpression` mutates are Ruby's methods.

## The catalog

Sixteen mutators make up the catalog. Fifteen have the names of Stryker mutators, and `RangeOperator` mutates a Ruby construct that no Stryker tool mutates. The run uses this table's order to choose which of two identical mutants it keeps (see [Mutants the mutators don't make](#mutants-the-mutators-dont-make)).

| Mutator | What it mutates | Prism nodes | Stryker counterpart |
| - | - | - | - |
| `ArithmeticOperator` | `+`, `-`, `*`, `/`, `%` between two operands | `CallNode` | StrykerJS `ArithmeticOperator` |
| `ArrayDeclaration` | Array literals and `Array.new` | `ArrayNode`, `CallNode` | StrykerJS `ArrayDeclaration` |
| `AssignmentOperator` | `+=`, `-=`, and the other operator assignments, `\|\|=`, `&&=` | the `OperatorWrite`, `OrWrite`, and `AndWrite` nodes | StrykerJS `AssignmentOperator` |
| `BlockStatement` | The body of a method, block, lambda, branch, loop, `when`, `in`, `begin`, `rescue`, or `ensure` | `StatementsNode` | StrykerJS `BlockStatement` |
| `BooleanLiteral` | `true`, `false`, `!`, `not`, the negation in `unless` and `until` | `TrueNode`, `FalseNode`, `CallNode`, `UnlessNode`, `UntilNode` | StrykerJS `BooleanLiteral` |
| `CallExpression` | A method call, removed | `CallNode` | StrykerJS `CallExpression` |
| `ConditionalExpression` | Conditions of `if`, `unless`, `elsif`, ternaries, `while`, `until`, and `in` guards, and comparisons and `&&`/`\|\|` elsewhere | the condition's node, `CallNode`, `AndNode`, `OrNode` | StrykerJS `ConditionalExpression` |
| `EqualityOperator` | `<`, `<=`, `>`, `>=`, `==`, `!=`, and the operands of `<=>` | `CallNode` | StrykerJS `EqualityOperator` |
| `LogicalOperator` | `&&`, `\|\|`, `and`, `or` | `AndNode`, `OrNode` | StrykerJS `LogicalOperator` |
| `MethodExpression` | Calls to a fixed list of core methods, swapped or removed | `CallNode` | StrykerJS `MethodExpression` |
| `ObjectLiteral` | Hash literals | `HashNode` | StrykerJS `ObjectLiteral` |
| `OptionalChaining` | Safe navigation, `&.` | `CallNode` and the call write nodes with the safe-navigation flag | StrykerJS `OptionalChaining` |
| `RangeOperator` | `..` and `...` | `RangeNode` | none |
| `Regex` | Regexp literals, and the pattern given to `Regexp.new` | `RegularExpressionNode`, `StringNode` | StrykerJS `Regex` |
| `StringLiteral` | String literals, interpolated strings, and heredocs | `StringNode`, `InterpolatedStringNode` | StrykerJS `StringLiteral` |
| `UnaryOperator` | Unary `-`, `+`, `~`, and signed numeric literals | `CallNode`, `IntegerNode`, `FloatNode`, `RationalNode`, `ImaginaryNode` | StrykerJS `UnaryOperator` |

### How to read the tables

In each mutator's table, the **Kills it** column says what a test has to do to tell the mutant from the original. It is for the readers of this design, who judge whether a pair is worth making. The report doesn't carry it: `description` is filled only for `Regex` mutants (see [What the report holds](#what-the-report-holds)). Italics name a part of the original, such as *left* or *receiver*.

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

The replacement text for an empty array is StrykerJS's. An array with no brackets, the right side of `a, b = 1, 2`, gets no mutant: `a, b = []` reads as a different assignment, not as an emptied array. StrykerJS turns `new Array()` into `new Array([])`, but in Ruby `Array.new([])` and `Array.new` both give an empty array, so `Array.new` with no arguments gets no mutant.

### `AssignmentOperator`

It mutates an operator assignment to any target: a local, instance, class, or global variable, a constant, an attribute (`a.b += 1`), or an index (`h[k] ||= []`).

| Original | Mutant | Kills it |
| - | - | - |
| `x += y` | `x -= y` | A test that reads *target* afterwards, with *value* not zero. |
| `x -= y` | `x += y` | A test that reads *target* afterwards, with *value* not zero. |
| `x *= y` | `x /= y` | A test that reads *target* afterwards. |
| `x /= y` | `x *= y` | A test that reads *target* afterwards. |
| `x %= y` | `x *= y` | A test that reads *target* afterwards. |
| `x <<= y` | `x >>= y` | A test that reads *target* afterwards. |
| `x >>= y` | `x <<= y` | A test that reads *target* afterwards. |
| `x &= y` | `x \|= y` | A test that reads *target* afterwards. |
| `x \|= y` | `x &= y` | A test that reads *target* afterwards. |
| `x \|\|= y` | `x &&= y` | A test that reads *target* when it starts as `nil` or `false`. |
| `x &&= y` | `x \|\|= y` | A test that reads *target* when it starts truthy. |

Ruby has no `++` or `--`, so `count += 1` is the idiom that StrykerJS's `UpdateOperator` covers in JavaScript, and it takes the `+=` pair here. The shared page says StrykerJS has no assignment mutator, but StrykerJS's code has `AssignmentOperator`, with the `&&=` and `||=` pairs that the page leaves out, so the catalog follows the code.

`||=` becomes `&&=`, as in StrykerJS, and not `=`. The common mistake with `@total ||= compute` is a memoized value that is `nil` or `false`, and `&&=` leaves the target as it started, so a test that reads the value once kills it. The mutant `@total = compute` gives the same value on every call and differs only in how often `compute` runs, so it would survive wherever the value is right, and its reader learns nothing about the value.

It makes no mutant when the right side is a string literal (`StringNode`, `InterpolatedStringNode`, `XStringNode`, or `InterpolatedXStringNode`), for every operator except `||=` and `&&=`, as StrykerJS skips it. `||=` and `&&=` keep their pairs, which swap one for the other whatever the right side holds.

### `BlockStatement`

It replaces a body with `nil`. A body is the `StatementsNode` of a `def` (an endless `def`'s expression included), a block (`{ }` or `do ... end`), a lambda, a branch of `if`, `unless`, or `case` (`else` included), a `while`, `until`, or `for` loop, a `when` or `in` clause, `begin`, `rescue`, or `ensure`.

| Original | Mutant | Kills it |
| - | - | - |
| `def apply(order)` with a body of `total = order.total` and `total.round(2)` | the body replaced with `nil` | A test that checks a value or an effect of this body. |
| `items.map { \|item\| item.price }` | `items.map { \|item\| nil }` | A test that checks a value or an effect of this body. |

The edit covers the body's statements, and the replacement is `nil`, because a Ruby body that is empty returns `nil`. It makes no mutant of a body that is already empty or is only `nil`, as StrykerJS doesn't mutate an empty block.

A class, module, or singleton class body isn't a body here, and neither is the top level of a file: emptying one would take every method in it, so every test that touches it fails and the survivor shows nothing new. StrykerJS likewise doesn't treat a class body as a block.

> [!NOTE]
> StrykerJS's `ArrowFunction` replaces an arrow function that has an expression body with `() => undefined`, and its `BlockStatement` empties one that has a block body. Ruby makes no such distinction: a block's or lambda's body is always a list of statements. So `BlockStatement` empties every block and lambda body, and the catalog has no `ArrowFunction`.

In JavaScript, an emptied `case` falls through to the next one, so StrykerJS empties a `case` under `ConditionalExpression`. In Ruby, an emptied `when` returns `nil` and runs nothing else, so it is an emptied body, and `BlockStatement` makes it.

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

### `CallExpression`

It replaces a method call with `nil`, whether the call's value is used or the call is a statement:

| Original | Mutant | Kills it |
| - | - | - |
| `order.save` | `nil` | A test that checks a value or an effect of `order.save`. |
| `notify(customer)` | `nil` | A test that checks a value or an effect of `notify(customer)`. |
| `raise ArgumentError, "rate must be positive"` | `nil` | A test that expects the error. |

It mutates a `CallNode` with a method name, with or without a receiver, arguments, or a block. It doesn't mutate:

- an operator call or an index (`a[0]`), which the operator mutators cover.
- an attribute or index write (`a.b = 1`, `h[k] = v`), which is an assignment, and StrykerJS doesn't remove assignments.
- a call that is the receiver of another call, such as `order.items` in `order.items.empty?`, because `nil.empty?` raises `NoMethodError` at once. The outermost call of a chain gets the mutant.
- a call that has another live mutant on it or inside it, such as `total.round(2)` when another mutator changes `total`. StrykerJS removes a call only under the same condition. The mutants inside already check that code.

`super` is a `SuperNode` or `ForwardingSuperNode`, not a call here, and StrykerJS doesn't remove `super(...)` either.

### `ConditionalExpression`

| Original | Mutant | Kills it |
| - | - | - |
| `if c`, `elsif c`, `unless c`, `c ? a : b`, `x if c`, `in pattern if c` | `true` in place of `c` | A test where *condition* is falsy. |
| the same | `false` in place of `c` | A test where *condition* is truthy. |
| `while c`, `x while c`, `begin ... end while c` | `false` in place of `c` | A test where the loop runs at least once. |
| `until c`, `x until c`, `begin ... end until c` | `true` in place of `c` | A test where the loop runs at least once. |
| `a == b`, `a < b`, `a && b`, and the other comparisons and logical operators, anywhere else | `true`, `false` | A test where the expression is falsy, for `true`, or truthy, for `false`. |
| an operand of `\|\|` or `or` that is a comparison or a logical operator | `false` | A test where *operand* is truthy and the rest is falsy. |
| an operand of `&&` or `and` that is a comparison or a logical operator | `true` | A test where *operand* is falsy and the rest is truthy. |

A condition of `if` or `unless` can be any expression, as in StrykerJS, so `if order` gets both mutants. A loop's condition becomes only the value that stops the loop at once, as in StrykerJS: the other value never ends the loop, so the run would end in a `Timeout` and cost its whole time limit. For `while` that value is `false`, and for `until` it is `true`.

An operand of `||` gets only `false`, and an operand of `&&` only `true`, as StrykerJS does. `true || y` is `true`, the mutant that the whole condition already gets, and `false && y` is `false`, the other one.

A condition that is already `true` or `false` gets no mutant of these, because one of its two mutants is the original. A comparison of the form `__FILE__ == $0` or `__FILE__ == $PROGRAM_NAME` gets none either, wherever it stands (see [Sites that get no mutant](#sites-that-get-no-mutant)).

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

A swapped operand that is a bare `defined?`, `not`, `and`, or `or` goes in parentheses. Each binds looser than `<=>`, so `a <=> defined? b` would swap to `defined? b <=> a`, which Ruby reads as `defined?(b <=> a)`. The mutant is `(defined? b) <=> a`. An operand that has parentheses of its own, such as `defined?(b)`, is swapped as written.

### `LogicalOperator`

| Original | Mutant | Kills it |
| - | - | - |
| `a && b` | `a \|\| b` | A test where one side is truthy and the other falsy. |
| `a \|\| b` | `a && b` | A test where one side is truthy and the other falsy. |
| `a and b` | `a or b` | A test where one side is truthy and the other falsy. |
| `a or b` | `a and b` | A test where one side is truthy and the other falsy. |

When the last `||` of a chain such as `a || b || c` becomes `&&`, the replacement is `(a || b) && c`, with the operands before that `||` in parentheses, because `a || b && c` would group the other way. The other three pairs need no parentheses, since each gives a replacement that groups as the original does.

StrykerJS also turns `a ?? b` into `a && b`. Ruby has no `??`: `name || "Guest"` is the idiom for a default, and it takes the `||` pair.

### `MethodExpression`

It mutates a call with a receiver to one of the methods listed, by its name alone, as StrykerJS and Stryker4s do, because the instrumenter can't know the receiver's class. A swap keeps the call's arguments and block. Each swap works in both directions.

| Original | Mutant | Kills it |
| - | - | - |
| `items.first` | `items.last` | A test with a collection whose first and last elements differ. |
| `items.min`, `items.min_by { }` | `items.max`, `items.max_by { }` | A test with elements that aren't all equal. |
| `name.start_with?(x)` | `name.end_with?(x)` | A test where *receiver* starts with the argument and doesn't end with it, or the reverse. |
| `name.upcase`, `name.upcase!` | `name.downcase`, `name.downcase!` | A test with a string that has letters. |
| `name.lstrip`, `name.lstrip!` | `name.rstrip`, `name.rstrip!` | A test with whitespace on one side only. |
| `name.ljust(10)` | `name.rjust(10)` | A test with a string shorter than the width. |
| `name.sub(a, b)`, `name.sub!(a, b)` | `name.gsub(a, b)`, `name.gsub!(a, b)` | A test where the pattern matches more than once. |
| `items.select { }`, `items.filter { }`, `items.select! { }` | `items.reject { }`, `items.reject { }`, `items.reject! { }` | A test where the block is true for some elements and false for others. `reject` becomes `select`. |
| `items.all? { }` | `items.any? { }` | A test where some elements match and some don't. |
| `items.take(n)`, `items.take_while { }` | `items.drop(n)`, `items.drop_while { }` | A test that checks which elements come back. |
| `items.index(x)` | `items.rindex(x)` | A test where the element occurs more than once. |
| `items.push(x)` | `items.unshift(x)` | A test with a nonempty array that checks the order. |
| `items.pop` | `items.shift` | A test with two or more different elements. |
| `price.ceil` | `price.floor` | A test with a value that isn't a whole number. |
| `n.even?` | `n.odd?` | A test that checks the result. |
| `n.positive?` | `n.negative?` | A test with a value that isn't zero. |

A removal replaces the whole call, its arguments and block included, with the receiver, as StrykerJS turns `s.trim()` into `s`:

| Original | Mutant | Kills it |
| - | - | - |
| `items.sort`, `items.sort { }`, `items.sort_by { }`, and their `!` forms | `items` | A test with elements out of order. |
| `items.reverse`, `items.reverse!` | `items` | A test with two or more different elements. |
| `items.uniq`, `items.uniq!` | `items` | A test with a repeated element. |
| `items.compact`, `items.compact!` | `items` | A test with a `nil` element. |
| `items.flatten`, `items.flatten!` | `items` | A test with a nested array. |
| `name.strip`, `name.strip!` | `name` | A test with leading or trailing whitespace. |
| `name.chomp`, `name.chomp!` | `name` | A test with a string that ends in a newline. |

The list holds methods of Ruby's core classes where a programmer's likely mistake is the other method of the pair, or a forgotten call, such as `sub` where every match had to be replaced. StrykerJS's list is of JavaScript's methods, and Stryker4s's of Scala's, and the pairs of the same mistakes appear here under Ruby's names: StrykerJS's `startsWith` and `endsWith`, `toUpperCase` and `toLowerCase`, `min` and `max`, `every` and `some`, Stryker4s's `filter` and `filterNot`, `take` and `drop`, `indexOf` and `lastIndexOf`, and Stryker.NET's `PadLeft` and `PadRight`, `Ceiling` and `Floor`, and `Append` and `Prepend`, which are `push` and `unshift` here.

`prepend` and `append` aren't swapped: in a class body, `prepend` is `Module#prepend`, and a mutant that calls `append` there raises at load. `freeze` is never removed (see [Sites that get no mutant](#sites-that-get-no-mutant)).

### `ObjectLiteral`

| Original | Mutant | Kills it |
| - | - | - |
| `{ rate: 0.1, cap: 50 }` | `{}` | A test that checks the hash's entries. |

A Ruby hash literal is the counterpart of a JavaScript object literal, so it takes StrykerJS's name. Keyword arguments, such as `Discount.new(rate: 0.1)`, are a `KeywordHashNode` and get no mutant: emptying them changes the call's arguments, and the call raises `ArgumentError` for a required keyword. An empty hash gets no mutant, as in StrykerJS.

### `OptionalChaining`

| Original | Mutant | Kills it |
| - | - | - |
| `order&.total` | `order.total` | A test where *receiver* is `nil`. |
| `order&.total = 0`, `order&.total += 1`, `order&.total \|\|= 0` | the same with `.` | A test where *receiver* is `nil`. |

Each `&.` in a chain such as `customer&.address&.city` gets a separate mutant.

The mutation goes from `&.` to `.` only, never from `.` to `&.`. A forgotten nil check is the mistake that `&.` exists to prevent, and a survivor of `&.` to `.` shows that no test passes `nil` there. A mutant from `.` to `&.` turns a `NoMethodError` on `nil` into a `nil` result, and only a test that expects the error would kill it. Few projects write such tests, so those survivors would be everywhere and show little.

It makes no mutant when the receiver can never be `nil`: `self`, or a literal other than `nil`.

### `RangeOperator`

| Original | Mutant | Kills it |
| - | - | - |
| `a..b`, `..b` | `a...b`, `...b` | A test at the end value, *right*. |
| `a...b`, `...b` | `a..b`, `..b` | A test at the end value, *right*. |

A range's end is where Ruby code has its off-by-one mistakes: `(0..items.size)` for `(0...items.size)`, or `1...10` in a `case` that was meant to include 10. A survivor shows that no test checks the end value. No Stryker tool has this mutator, because JavaScript, C#, and Scala have no range literal written with `..` and `...`.

An endless range (`a..`, `a...`) gets no mutant: the two forms iterate, slice, and test membership the same way. A flip-flop (a range in a condition, a `FlipFlopNode`) gets none either.

### `Regex`

It mutates the pattern of a regexp literal (`/.../` or `%r{...}`, a `RegularExpressionNode`) and the string literal given as the first argument of `Regexp.new`. It parses each pattern with the [regexp_parser](https://github.com/ammar/regexp_parser) gem, in the orchestrator only, and makes these mutants:

| Mutation | Original | Mutant | Kills it |
| - | - | - | - |
| Anchor removed | `/^\d+$/`, `/\A\d+\z/` | `/\d+$/`, `/^\d+/`, `/\d+\z/`, `/\A\d+/` | A test with a string that has the match away from that end. |
| Line anchor to string anchor | `/^\d+$/` | `/\A\d+$/`, `/^\d+\z/` | A test with a string that has a newline before or after the match. |
| Character class negated | `/[aeiou]/` | `/[^aeiou]/` | A test with a string that the class matches. |
| Shorthand class negated | `/\d/`, `/\s/`, `/\w/` | `/\D/`, `/\S/`, `/\W/` | A test with a string that the class matches. |
| Property negated | `/\p{Alpha}/` | `/\P{Alpha}/` | A test with a string that the property matches. |
| Quantifier removed | `/ab+c/`, `/ab?c/`, `/ab{2,4}c/` | `/abc/` | A test where the quantified character or group is absent or repeated. |
| Lookaround negated | `/a(?=b)/` | `/a(?!b)/` | A test where the lookaround holds. |

These are the mutations at level 1 of [Weapon regeX](https://github.com/stryker-mutator/weapon-regex), which StrykerJS and Stryker4s run, with Ruby's string anchors `\A`, `\z`, and `\Z` added to anchor removal, and one mutation from Weapon regeX's level 2: a line anchor becomes a string anchor. In Ruby, `^` matches at the start of any line and `$` at the end of any line, whatever the flags. A pattern that validates input with `^` and `$` therefore accepts a string with a newline in it, and the survivor of `^` to `\A` shows that no test sends one.

The mutator keeps the pattern's flags. It compiles each mutant with `Regexp.new` in the orchestrator and drops one that raises `RegexpError`. It makes no mutant of a pattern with interpolation (`InterpolatedRegularExpressionNode`), whose text isn't known until it runs. When regexp_parser can't parse a pattern, the pattern gets no mutant, and the run prints a warning with the file and line.

Weapon regeX has no Ruby version, and **Stryker (for Ruby)** doesn't run JavaScript or Scala, so it applies the mutations itself, to the tree that regexp_parser gives.

### `StringLiteral`

| Original | Mutant | Kills it |
| - | - | - |
| `"Free shipping"`, `'Free shipping'`, `?a` | `""` | A test that checks the string. |
| `""`, `''` | `"Stryker was here!"` | A test that checks that the string is empty. |
| `"Total: #{total}"`, `"a" "b"` | `""` | A test that checks the string. |
| `<<~TEXT` | `""` | A test that checks the string. |

The replacement texts are StrykerJS's. An interpolated string, and adjacent literals joined into one, are mutated whole, as StrykerJS mutates a template literal whole. A string inside an interpolation, or a part of `"a" "b"`, gets no separate mutant. The edit for a heredoc covers only its opener, such as `<<~TEXT`, because that is the heredoc node's range, and its body stays where it is ([Kinds of site](mutant-placement.md#literals)).

It makes no mutant of:

- the key of a hash pair, such as `"rate"` in `{ "rate" => 0.1 }`, as StrykerJS doesn't mutate an object's keys;
- an element of `%w[]`, whose syntax has no empty element (`ArrayDeclaration` covers the array);
- the pattern given to `Regexp.new`, which `Regex` covers;
- a backtick or `%x` command (`XStringNode`, `InterpolatedXStringNode`), because the mutant makes the tests run a different command on the machine.

A string that Ruby freezes under `frozen_string_literal: true` is replaced by one that Ruby freezes too, so frozenness doesn't change ([Kinds of site](mutant-placement.md#literals)).

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

## Shared groups with no Ruby mutator

| Stryker mutator | Why the catalog has no counterpart |
| - | - |
| `UpdateOperator` (`++`, `--`) | Ruby has no `++` or `--`. `count += 1` takes `AssignmentOperator`'s pair. |
| `ArrowFunction` | Ruby's blocks and lambdas always have a body of statements, which `BlockStatement` empties. |
| Stryker.NET's `Checked`, `NullCoalescing`, `Bitwise`, `Linq`, `Math`, and `StringMethod` | They mutate C# constructs and .NET methods. The methods that matter in Ruby are in `MethodExpression`. |

## Constructs that get no mutator

Each of these was left out of the catalog because its survivors would rarely be worth acting on:

| Construct | Why no mutator makes a mutant of it |
| - | - |
| `nil` | `nil` and `false` behave the same in a condition, and any other replacement raises at once. |
| Symbols, `&:sym` | A symbol is the name of a method, key, or option, and a symbol nobody defines raises `NoMethodError`, `KeyError`, or `ArgumentError` at the first test that reaches it, which shows nothing that coverage doesn't. |
| Number literals | No Stryker tool mutates them. The boundary mutants of `EqualityOperator` and `RangeOperator` test the values where off-by-one mistakes matter. |
| `.` to `&.` | See [`OptionalChaining`](#optionalchaining). |
| `case`/`in` patterns, flip-flops, `defined?`, `yield`, `super` | No Stryker tool has a counterpart, and their mutants mostly raise or change nothing a test sees. Their bodies and guards still get mutants. |

## Defaults

Every mutator in the catalog runs when nothing is configured, as every StrykerJS and Stryker4s mutator does. The catalog leaves out the pairs whose survivors wouldn't be worth acting on, so there is no second list of mutators that are off by default to learn. Stryker.NET's mutation levels, which leave some mutators off to save run time, have no counterpart: the configuration takes StrykerJS's option names ([#3](https://github.com/setdef/stryker_for_ruby/issues/3)), and StrykerJS has no levels.

### Turning mutators off

List a mutator in `mutator.excludedMutations` to turn it off for the whole run. The option has StrykerJS's name and form: an array of mutator names, in the configuration file only, with `[]` as its default.

```json
{
  "mutator": {
    "excludedMutations": ["StringLiteral", "Regex"]
  }
}
```

A name matches exactly, with letter case, as in StrykerJS. Each mutant of an excluded mutator is still made and reported, with the status `Ignored` and the `statusReason` `Ignored because of excluded mutation "StringLiteral"`, StrykerJS's text. It gets no switch and never runs. An `Ignored` mutant counts toward the total but not toward the mutation score, as the [shared metrics](https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/) define.

A name that isn't a mutator name is a configuration error, and the run stops before it parses any file, with an error that lists the valid names. StrykerJS accepts an unknown name and ignores it, so a misspelled name would leave its mutator running with no warning. Stryker.NET stops with an `InputException` (`Invalid excluded mutation ...`) that lists the valid names, and Stryker4s stops with a configuration error that lists them. The run stops as they do.

```json
{
  "mutator": {
    "excludedMutations": ["Equality"]
  }
}
```

The run stops, because `Equality` is Stryker.NET's short name, and the name here is `EqualityOperator`.

To turn a mutator off at one site, use a [disable comment](#the-disable-comment).

### Logger calls and `# :nocov:`

No site is ignored by default. A call to a logger gets the same mutants as any other call, and code between `# :nocov:` comments, the markers that SimpleCov reads, gets its mutants too. A project that doesn't want a mutant uses a disable comment, and an `Ignored` mutant comes only from `mutator.excludedMutations` or a disable comment.

No other Stryker tool ignores a logging call by default. StrykerJS ships only an `angular` ignorer, and a maintainer wrote in [stryker-js#1174](https://github.com/stryker-mutator/stryker-js/issues/1174) that a log statement that no test checks shouldn't be swept under a rug. The default of Stryker.NET's `ignore-methods` is empty. Only Stryker.NET honors a coverage exclusion, `[ExcludeFromCodeCoverage]`, and StrykerJS and Stryker4s honor none.

## Sites that get no mutant

These sites get no mutant from any mutator, and no switch. The table gives each rule's reason.

| Site | Reason |
| - | - |
| A call with no receiver to `require`, `require_relative`, `load`, or `autoload`, and `autoload` called on a module: the call's arguments, and the call's removal | A changed path loads another file or raises `LoadError`, and a removed `require` or `autoload` either raises `NameError` or changes nothing because another file loaded the same code. Each such mutant is static, so it would cost a fresh process and the whole suite. [Mutant placement](mutant-placement.md#sites-that-get-no-mutant) gives the rule for the arguments. |
| Comments, magic comments such as `# frozen_string_literal: true`, and the data after `__END__` | They aren't code that Prism gives a mutator. The instrumenter keeps them byte for byte ([Splicing into the original bytes](mutant-placement.md#splicing-into-the-original-bytes)). |
| `freeze` | No mutator removes a call to `freeze`, or the `-` or `+` before a string literal. The receiver behaves the same unfrozen unless some code changes it, and only a test that expects `FrozenError` would kill the mutant, so it would survive on every frozen constant. |
| The comparison `__FILE__ == $0` or `__FILE__ == $PROGRAM_NAME`, either way round, wherever it stands | A mutant that makes the comparison true, such as `true` in its place or `!=` for `==`, runs the file's script code inside the test process, where it does whatever the script does. The comparison gets none whether it is a condition or a value. |
| A call with no receiver to `sig` with a block, and everything inside the block | It is a [Sorbet](https://sorbet.org) type signature, the counterpart of the type annotations that StrykerJS never mutates. The block is out of every mutator's reach, so no mutator makes a mutant of a call, a literal, or an operator inside it. |
| A backtick or `%x` command | See [`StringLiteral`](#stringliteral). |
| Code inside `BEGIN { }`, and a mutant with no one-line form | See [Mutant placement](mutant-placement.md#sites-that-get-no-mutant). |
| The removal of a call with no receiver to `private`, `protected`, `private_constant`, or `private_class_method` | No Stryker tool has a mutator that changes visibility, so `CallExpression` leaves these calls alone, as it leaves `require` alone. |

### Test files

The `mutate` option chooses the files that get mutants ([Architecture](architecture.md#the-pipeline)). Its default patterns leave out `test/`, `spec/`, `*_test.rb`, and `*_spec.rb`, as StrykerJS's default leaves out `__tests__` directories and file names that end in `test` or `spec`. A pattern that the project writes can still match a test file, and that file then gets mutants: no check stops it, as none stops it in StrykerJS. A mutant in a test file changes the test that judges it.

## Equivalent mutants

An equivalent mutant behaves the same as the original for every input, so no test can kill it, and its survivor wastes its reader's time. No Stryker tool detects equivalent mutants in general, and neither does **Stryker (for Ruby)**. The mutators avoid the ones that the source text alone proves equivalent, and the disable comment marks the rest.

### Mutants the mutators don't make

- **Identical mutants.** When two live mutants give the same text for the whole file, the run keeps one: the mutant whose mutator comes first in [the catalog](#the-catalog), and between two of the same mutator, the one whose site starts first. In `def save` with the single statement `write` as its body, `BlockStatement` and `CallExpression` both replace `write` with `nil`, and the run keeps `BlockStatement`'s. In `!!ready`, removing either `!` gives `!ready`, and the run keeps the outer one. The run compares only live mutants, so an `Ignored` mutant never removes a live one.
- **A mutant equal to the original.** A mutant whose text for the whole file is the original's is never made, such as `x <=> x` swapped.
- **Mutants whose equivalence the syntax shows.** Each mutator's section lists them: a condition that is already `true` or `false`, a body that is already empty or `nil`, an empty hash, `-0`, `-0r`, and `-0i`, an endless range, `&.` on `self` or a literal, and `Array.new` given `[]`.

A mutant whose equivalence depends on a value's class or range at run time is made. For example, `x > 0` and `x >= 1` agree when `x` is an `Integer`, and differ when it is `0.5`, and the instrumenter can't know which `x` holds. Leaving such a mutant out would hide every real mistake that it stands for. Mark it with a disable comment once you've checked it.

### The disable comment

With a disable comment, you turn off mutators for one line, or for the rest of a file, and record why. It follows StrykerJS's grammar in Ruby's comment syntax:

```ruby
# Stryker [disable|restore] [next-line] <mutators>[: <reason>]
```

- `disable` turns the mutators off and `restore` turns them back on.
- With `next-line`, the comment applies to the mutants whose site starts on the next line that holds code. Without it, the comment applies from the comment's line to the end of the file, or until a `restore` for the same mutators.
- `<mutators>` is a comma-separated list of mutator names, or `all`. Names match without regard to letter case, as in StrykerJS. An unknown name makes the run print a warning with the file and line, as StrykerJS does, and the rest of the comment still applies.
- `<reason>`, after a colon, becomes the mutant's `statusReason`.

Each mutant that a disable comment covers is made and reported with the status `Ignored`, and its `statusReason` is the reason, or StrykerJS's text, `Ignored using a comment`, when the comment has none. It gets no switch and never runs.

The comment's text after `#` must match StrykerJS's pattern, `/^\s?Stryker (disable|restore)(?: (next-line))? ([a-zA-Z, ]+)(?::(.+)?)?/`. So the comment starts with `#Stryker`, or with `#`, one whitespace character, and `Stryker`, and nothing else may come before `Stryker`.

A fee that starts after a free allowance has an equivalent mutant: at exactly `FREE_HOURS`, both branches give `0`, so `hours >= FREE_HOURS` behaves as `hours > FREE_HOURS` does. Mark it on the line before:

```ruby
# Stryker disable next-line EqualityOperator: at FREE_HOURS both branches give 0, so the >= mutant is equivalent
fee = (hours > FREE_HOURS) ? (hours - FREE_HOURS) * RATE : 0
```

Both of that line's `EqualityOperator` mutants are `Ignored` with that reason, the `<=` mutant as well, which isn't equivalent: a comment lists mutators, not pairs. The line's `ConditionalExpression` mutants still run.

A comment that doesn't match the pattern is an ordinary comment, and one that matches with an unknown name turns nothing off:

```ruby
# Wrong: "next line" has a space where the grammar needs a hyphen. The comment matches
# the pattern, and its whole list, "next line EqualityOperator", is one unknown name,
# so the run prints a warning and the mutants on the next line stay live.
# Stryker disable next line EqualityOperator
total -= total * @rate if order.quantity > BULK_THRESHOLD
```

```ruby
# Wrong: "@stryker" isn't "Stryker", so this is an ordinary comment.
# @stryker disable next-line all
total -= total * @rate if order.quantity > BULK_THRESHOLD
```

A condition that is always true while the tests run, such as `Rails.env.test?`, has a `ConditionalExpression` mutant that no test can kill. Mark it on the line before:

```ruby
# Stryker disable next-line ConditionalExpression: Rails.env.test? is always true under the tests
deliver_later unless Rails.env.test?
```

To turn off every mutator for part of a file:

```ruby
# Stryker disable all: generated from the carrier's rate table
RATES = {
  # The generated rates go here.
}.freeze
# Stryker restore all
```

## What the report holds

The JSON reporter writes each mutant as an entry in `files.<path>.mutants` of the [mutation testing report schema](https://github.com/stryker-mutator/mutation-testing-elements/tree/master/packages/report-schema), and the HTML reporter shows the same entry. The report holds what the person or agent who reads a survivor needs to find the mutant and the tests that ran it: where the mutant is, what it replaced, and which tests ran it. It doesn't say what a test has to do to kill the mutant: the **Kills it** column of the mutator's table does, and only for the readers of this design.

For this file, `lib/shop/discount.rb`, the shared example of the rest of this section:

```ruby
module Shop
  class Discount
    BULK_THRESHOLD = 10
    private_constant :BULK_THRESHOLD

    def initialize(rate:)
      @rate = rate
    end

    # Returns the order's total, less the discount for a bulk order.
    def apply(order)
      return order.total if order.items.empty?

      total = order.total
      total -= total * @rate if order.quantity > BULK_THRESHOLD
      total.round(2)
    end
  end
end
```

one survivor of the comparison on line 15 is reported like this:

```json
{
  "id": "17",
  "mutatorName": "EqualityOperator",
  "replacement": "order.quantity >= BULK_THRESHOLD",
  "location": { "start": { "line": 15, "column": 33 }, "end": { "line": 15, "column": 64 } },
  "status": "Survived",
  "coveredBy": ["Shop::DiscountTest#test_bulk_order_gets_the_rate", "Shop::DiscountTest#test_small_order_pays_full_price"],
  "testsCompleted": 2,
  "static": false
}
```

Both tests that reached the comparison passed. The **Kills it** column of `EqualityOperator` says that a test where *left* equals *right* kills this mutant, which here is a test of an order of exactly 10 items.

| Field | What it holds |
| - | - |
| `id` | The mutant's integer ID in the run, as a string. |
| `mutatorName` | The mutator's name from [the catalog](#the-catalog), exactly as `mutator.excludedMutations` and the disable comment take it. |
| `replacement` | The text of the mutant's edit: what replaces the range in `location`. |
| `location` | The edit's range in the original file, with lines and columns counted from 1, and the end excluded. Columns count UTF-16 code units, as Prism's `start_code_units_column(Encoding::UTF_16LE)` gives them, plus 1. |
| `description` | For a `Regex` mutant, one sentence on what changed in the pattern ([The description](#the-description)). Left out for every other mutant. |
| `status` | The status from [the architecture](architecture.md#the-pipeline), `CompileError` ([Mutants that aren't valid Ruby](mutant-placement.md#mutants-that-arent-valid-ruby)), `NoCoverage`, or `Ignored`. |
| `statusReason` | The reason for the status, from the table in [The status reason](#the-status-reason). Left out for `Survived` and `NoCoverage`. |
| `coveredBy` | The IDs of the tests whose bucket holds the mutant in the dry run ([Coverage](coverage.md#hits)). For a runtime mutant, these are the tests its run ran. A static mutant's run includes every test, and its `coveredBy` still lists only the tests that recorded a hit, as StrykerJS lists them. |
| `killedBy` | The ID of the test that killed it. A run stops at its first failing test, so it lists one. |
| `testsCompleted` | The number of tests that finished in the mutant's run. |
| `duration` | The run's time in milliseconds. |
| `static` | `true` when the plan ran the mutant as a static mutant ([Coverage](coverage.md#how-the-plan-uses-the-map)). |

The report's `testFiles` lists each test with its name and its file and location, when the test runner adapter gives them, so each ID in `coveredBy` and `killedBy` leads to a test that the reader can open and extend.

### Why the columns count UTF-16 code units

The HTML report shows a selected mutant as a diff: it marks the lines in `location` as removed, and below them shows the same lines with `replacement` put in place of the range. It finds the range by JavaScript string index, which counts UTF-16 code units. A column in bytes or characters would put the replacement in the wrong place on any line with non-ASCII text before the site, such as `"Prix: #{prix} €" if total > 100`.

> [!WARNING]
> `replacement` has to be exactly the text that replaces `location`'s range. Anything else, such as the whole mutant line or the one-line text in the switch, makes the HTML report show a diff of code that the mutant never ran. The HTML report doesn't show `replacement` as a separate field, only inside that diff.

### The status reason

`statusReason` takes StrykerJS's text wherever StrykerJS has one, because this project's names follow StrykerJS, and Stryker4s's text elsewhere.

| Status | `statusReason` | Whose text |
| - | - | - |
| `Killed` | The failure message of the test that killed it. | StrykerJS and Stryker4s |
| `Survived` | Left out. | StrykerJS |
| `NoCoverage` | Left out. | StrykerJS |
| `Timeout` | `Timeout of <N> ms exceeded.`, where N is the time limit of the run, such as `Timeout of 1500 ms exceeded.` | Stryker4s |
| `RuntimeError` | The message of the error that ended the run. | StrykerJS |
| `Ignored`, by `mutator.excludedMutations` | `Ignored because of excluded mutation "<name>"`, with the mutator's name. | StrykerJS |
| `Ignored`, by a disable comment | The comment's reason, or `Ignored using a comment` when it has none. | StrykerJS |

StrykerJS writes a reason for a `Timeout` only when a hit limit stops the run, and none when the clock does. Stryker4s writes its text for every timeout, and the run does the same.

### The description

`description` is filled only for `Regex` mutants, as Stryker.NET and Stryker4s fill it, and it says what changed in the pattern. StrykerJS never fills it. No Stryker tool puts the original code or a hint about killing the mutant there: the **Kills it** sentences stay in this design and out of the report.

The sentence names the part of the pattern by its text and says what happened to it and where, in the form of Stryker.NET's regex mutants. The offset counts characters in the pattern, from 0. The kind is `Anchor`, `Quantifier`, `Character class`, `Character class shorthand`, `Property`, or `Lookaround`. For `/^\d+$/`, three of the mutants have these descriptions:

```text
Anchor "^" was removed at offset 0.
Anchor "^" was replaced with "\A" at offset 0.
Character class shorthand "\d" was replaced with "\D" at offset 1.
```

A `Regex` mutant has a description whatever its status, `Ignored` included.

## ERB

Mutants in an ERB template come only from sites inside one tag ([#9](https://github.com/setdef/stryker_for_ruby/issues/9)): a switch never wraps a node that spans tags, because its mutant branch would have to hold the HTML between them. Every mutator makes the same pairs in a tag as in a `.rb` file. What differs:

- **`BlockStatement` makes no mutant of a body that spans tags,** such as the body of `<% items.each do |item| %>` ... `<% end %>`, which is HTML and other tags. A body inside one tag, such as `<%= items.map { |item| item.name }.join(", ") %>`, gets its mutant.
- **`BooleanLiteral` makes no mutant of an `unless` or `until` that spans tags.** The edit covers only the keyword, but the switch has to wrap the whole `UnlessNode` or `UntilNode`. Its condition is inside one tag, so it gets its `ConditionalExpression` mutants.
- **`CallExpression` and `StringLiteral` in an output tag change what the page renders.** `<%= order.total %>` becomes `<%= nil %>`, which renders nothing. A test that checks the rendered page kills the mutant.
- **Every ERB mutant is a runtime mutant,** because a template runs only while it renders ([#9](https://github.com/setdef/stryker_for_ruby/issues/9)), so `static` is `false`.
- **`location` is in the template file,** at the template's lines and columns.
- **The disable comment** is a Ruby comment: it goes inside a Ruby tag, or in an ERB comment tag, as `<%# Stryker disable next-line all %>`. Its next line is the next line of the template that holds a Ruby tag. StrykerJS reads a disable comment in the comment syntax of the embedded language, inside the `<script>` block of a `.vue` or `.html` file, and reads no HTML comment, because it parses no markup for mutants. **Stryker (for Ruby)** mutates no template markup either, so there is no markup-comment form to follow. The extractor blanks an ERB comment tag and a tag whose code is a one-line `#` comment ([The extraction rules](erb.md#the-extraction-rules)), so Prism lists no comment for either. The extractor records the text and line of each, and the disable-comment reader reads those along with Prism's comments, so a disable comment in either form takes effect.

The sites that get no mutant are the same in a template as in a `.rb` file.

## What this design doesn't do

- It doesn't detect equivalent mutants beyond the ones the source text proves.
- It doesn't use a value's class: `MethodExpression` and the operator mutators match by name and syntax alone.
- It has no mutation levels: every mutator runs unless `mutator.excludedMutations` lists it.
- It doesn't ignore a site by default: logger calls and code between `# :nocov:` comments get mutants.
- It doesn't put the **Kills it** text in the report.
- It doesn't mutate symbols, numbers other than their sign, `nil`, or `case`/`in` patterns.
- It doesn't make a mutant of a template node that spans ERB tags.
