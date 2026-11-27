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

A mutator for a Ruby construct that no Stryker tool mutates follows the organization's naming rule, from the thread behind the shared page ([stryker-handbook#11](https://github.com/stryker-mutator/stryker-handbook/issues/11)): a name follows the construct, is language-neutral and singular, and ends in a category word, one of Operator, Literal, Expression, Statement, or Declaration. StrykerJS's `OptionalChaining` is a name in the catalog that ends in none of them. `RangeOperator`, which swaps `..` and `...`, is the one name that no Stryker tool has, because no Stryker tool mutates a range. Every name is letters only, because StrykerJS's disable-comment grammar accepts only letters, commas, and spaces in its list of names.

Where the sources disagree on the pairs, the catalog follows StrykerJS's code, because the name in `mutatorName` is StrykerJS's: a reader who knows what StrykerJS's `EqualityOperator` makes finds the same pairs here. Each place where the catalog departs from StrykerJS's pairs gives its reason, and the methods that `MethodExpression` mutates are Ruby's methods.

## The catalog

Fourteen mutators make up the catalog. Thirteen have the names of Stryker mutators, and `RangeOperator` mutates a Ruby construct that no Stryker tool mutates. The run uses this table's order to choose which of two identical mutants it keeps (see [Mutants the mutators don't make](#mutants-the-mutators-dont-make)).

| Mutator | What it mutates | Prism nodes | Stryker counterpart |
| - | - | - | - |
| `ArithmeticOperator` | `+`, `-`, `*`, `/`, `%` between two operands | `CallNode` | StrykerJS `ArithmeticOperator` |
| `ArrayDeclaration` | Array literals and `Array.new` | `ArrayNode`, `CallNode` | StrykerJS `ArrayDeclaration` |
| `AssignmentOperator` | `+=`, `-=`, and the other operator assignments, `\|\|=`, `&&=` | the `OperatorWrite`, `OrWrite`, and `AndWrite` nodes | StrykerJS `AssignmentOperator` |
| `BlockStatement` | The body of a method, block, lambda, branch, loop, `when`, `in`, `begin`, `rescue`, or `ensure` | `StatementsNode` | StrykerJS `BlockStatement` |
| `BooleanLiteral` | `true`, `false`, `!`, `not`, the negation in `unless` and `until` | `TrueNode`, `FalseNode`, `CallNode`, `UnlessNode`, `UntilNode` | StrykerJS `BooleanLiteral` |
| `ConditionalExpression` | Conditions of `if`, `unless`, `elsif`, ternaries, `while`, `until`, and `in` guards, and comparisons and `&&`/`\|\|` elsewhere | the condition's node, `CallNode`, `AndNode`, `OrNode` | StrykerJS `ConditionalExpression` |
| `EqualityOperator` | `<`, `<=`, `>`, `>=`, `==`, `!=`, and the operands of `<=>` | `CallNode` | StrykerJS `EqualityOperator` |
| `LogicalOperator` | `&&`, `\|\|`, `and`, `or` | `AndNode`, `OrNode` | StrykerJS `LogicalOperator` |
| `MethodExpression` | Calls to a fixed list of core methods, swapped or removed | `CallNode` | StrykerJS `MethodExpression` |
| `ObjectLiteral` | Hash literals | `HashNode` | StrykerJS `ObjectLiteral` |
| `OptionalChaining` | Safe navigation, `&.` | `CallNode` and the call write nodes with the safe-navigation flag | StrykerJS `OptionalChaining` |
| `RangeOperator` | `..` and `...` | `RangeNode` | none |
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

Ruby has no `++` or `--`, so `count += 1` is the idiom that StrykerJS's `UpdateOperator` covers in JavaScript, and it takes the `+=` pair here. The shared page says StrykerJS has no assignment mutator, but StrykerJS's code has `AssignmentOperator`, with the `&&=` and `||=` pairs that the page leaves out, so the catalog follows the code. `**=` and `^=` get no mutant, as no pair is listed for them.

`||=` becomes `&&=`, as in StrykerJS, and not `=`. The common mistake with `@total ||= compute` is a memoized value that is `nil` or `false`, and `&&=` leaves the target as it started, so a test that reads the value once kills it. The mutant `@total = compute` gives the same value on every call and differs only in how often `compute` runs, so it would survive wherever the value is right, and its reader learns nothing about the value.

It makes no mutant when the right side is a string literal (`StringNode`, `InterpolatedStringNode`, `XStringNode`, or `InterpolatedXStringNode`), for every operator except `||=` and `&&=`, as StrykerJS skips it. `||=` and `&&=` keep their pairs, which swap one for the other whatever the right side holds.

### `BlockStatement`

It replaces a body with `nil`. A body is the `StatementsNode` of a `def` (an endless `def`'s expression included), a block (`{ }` or `do ... end`), a lambda, a branch of `if`, `unless`, or `case` (`else` included), a `while`, `until`, or `for` loop, a `when` or `in` clause, `begin`, `rescue`, or `ensure`.

| Original | Mutant | Kills it |
| - | - | - |
| `def apply(order)` with a body of `total = order.total` and `total.round(2)` | the body replaced with `nil` | A test that checks a value or an effect of this body. |
| `items.map { \|item\| item.price }` | `items.map { \|item\| nil }` | A test that checks a value or an effect of this body. |

The edit covers the body's statements, and the replacement is `nil`, because a Ruby body that is empty returns `nil`. It makes no mutant of a body that is already empty or is only `nil`, as StrykerJS doesn't mutate an empty block. The `else` of a `begin ... rescue ... else` is a body too, with the others of its `begin`.

A class, module, or singleton class body isn't a body here, and neither is the top level of a file: emptying one would take every method in it, so every test that touches it fails and the survivor shows nothing new. StrykerJS likewise doesn't treat a class body as a block. The statements inside parentheses or an interpolation aren't a body either, and neither is the pattern of a guard, `in pattern if condition`, which Prism holds as the statements of an `if`.

> [!NOTE]
> StrykerJS's `ArrowFunction` replaces an arrow function that has an expression body with `() => undefined`, and its `BlockStatement` empties one that has a block body. Ruby makes no such distinction: a block's or lambda's body is always a list of statements. So `BlockStatement` empties every block and lambda body, and the catalog has no `ArrowFunction`.

In JavaScript, an emptied `case` falls through to the next one, so StrykerJS empties a `case` under `ConditionalExpression`. In Ruby, an emptied `when` returns `nil` and runs nothing else, so it is an emptied body, and `BlockStatement` makes it.

A loop whose body is emptied can run forever when the body is what ends it. The run ends such a mutant at its time limit, with the status `Timeout` ([Time limits and kills](loading-and-isolation.md#time-limits-and-kills)).

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

A comparison is `==`, `!=`, `<`, `<=`, `>`, or `>=`, written as an operator. `<=>` isn't one, because its result isn't a truth value. A logical operator is `&&`, `||`, `and`, or `or`. Parentheses around one statement are ignored: in `if (a == b)` and in `x || (a == b)`, the comparison is the condition and the operand, and it gets the mutants of one.

A condition of `if` or `unless` can be any expression, as in StrykerJS, so `if order` gets both mutants. A loop's condition becomes only the value that stops the loop at once, as in StrykerJS: the other value never ends the loop, so the run would end in a `Timeout` and cost its whole time limit. For `while` that value is `false`, and for `until` it is `true`.

An operand of `||` gets only `false`, and an operand of `&&` only `true`, as StrykerJS does. `true || y` is `true`, the mutant that the whole condition already gets, and `false && y` is `false`, the other one.

A condition that is already `true` or `false` gets no mutant of these, because one of its two mutants is the original, and `BooleanLiteral` already makes the other. A comparison of the form `__FILE__ == $0` or `__FILE__ == $PROGRAM_NAME` gets none either, wherever it stands, and neither does a node that has such a comparison as its condition or operand: an `if`, `unless`, `elsif`, `while`, `until`, or ternary whose condition it is, an `&&`, `||`, `and`, or `or` with it as an operand, and a `!` or `not` of it (see [Sites that get no mutant](#sites-that-get-no-mutant)). The mutants inside such a node, in its body or in an operand that isn't the comparison, are made.

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

It makes no mutant when the receiver can never be `nil`: `self`, or a literal other than `nil`. The literals are numbers, strings, commands, symbols, regexps, arrays, hashes, `true`, `false`, lambdas, `__FILE__`, `__LINE__`, and `__ENCODING__`. A literal in parentheses doesn't count: Prism makes it a `ParenthesesNode`, the same as any other expression in parentheses.

### `RangeOperator`

| Original | Mutant | Kills it |
| - | - | - |
| `a..b`, `..b` | `a...b`, `...b` | A test at the end value, *right*. |
| `a...b`, `...b` | `a..b`, `..b` | A test at the end value, *right*. |

A range's end is where Ruby code has its off-by-one mistakes: `(0..items.size)` for `(0...items.size)`, or `1...10` in a `case` that was meant to include 10. A survivor shows that no test checks the end value. No Stryker tool has this mutator, because JavaScript, C#, and Scala have no range literal written with `..` and `...`.

An endless range (`a..`, `a...`) gets no mutant: the two forms iterate, slice, and test membership the same way. A flip-flop (a range in a condition, a `FlipFlopNode`) gets none either.

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
| A node whose condition or operand is that comparison, with any parentheses around the comparison ignored: an `if`, `unless`, `elsif`, `while`, `until`, or ternary condition, an operand of `&&`, `\|\|`, `and`, or `or`, and the operand of `!` or `not` | A mutator that changes such a node makes no mutant of it, `LogicalOperator`, `BooleanLiteral`, and `ConditionalExpression` among them, because each mutant would change whether the comparison decides, and run the file's script code inside the test process, as `true` in place of the comparison does. `__FILE__ == $0 and main`, `unless __FILE__ == $0`, and `!(__FILE__ == $0)` get none, as the bare `if __FILE__ == $0` gets none. The mutants inside such a node, in its body or in an operand that isn't the comparison, are made. |
| A call with no receiver to `sig` with a block, and everything inside the block | It is a [Sorbet](https://sorbet.org) type signature, the counterpart of the type annotations that StrykerJS never mutates. The block is out of every mutator's reach, so no mutator makes a mutant of a call, a literal, or an operator inside it. |
| Code inside `BEGIN { }`, and a mutant with no one-line form | See [Mutant placement](mutant-placement.md#sites-that-get-no-mutant). |

### Test files

The default of the `mutate` option leaves out test files ([`mutate`](../../configuration.md#mutate)), as StrykerJS's default leaves out `__tests__` directories and file names that end in `test` or `spec`. A pattern that the project writes can still match a test file, and that file then gets mutants: no check stops it, as none stops it in StrykerJS.

## Equivalent mutants

An equivalent mutant behaves the same as the original for every input, so no test can kill it, and its survivor wastes its reader's time. No Stryker tool detects equivalent mutants in general, and neither does **Stryker (for Ruby)**. The mutators avoid the ones that the source text alone proves equivalent.

### Mutants the mutators don't make

- **Identical mutants.** When two mutants give the same text for the whole file, the run keeps one: the mutant whose mutator comes first in [the catalog](#the-catalog), and between two of the same mutator, the one whose site starts first. In `!!ready`, removing either `!` gives `!ready`, and the run keeps the outer one.
- **A mutant equal to the original.** A mutant whose text for the whole file is the original's is never made, such as `x <=> x` swapped.
- **Mutants whose equivalence the syntax shows.** Each mutator's section lists them: `-0`, `-0r`, `-0i`, `Array.new` given no argument or `[]`, an empty hash, a body that is already empty or `nil`, a condition that is already `true` or `false`, an endless range, and `&.` on `self` or a literal.

A mutant whose equivalence depends on a value's class or range at run time is made. For example, `x > 0` and `x >= 1` agree when `x` is an `Integer`, and differ when it is `0.5`, and the instrumenter can't know which `x` holds. Leaving such a mutant out would hide every real mistake that it stands for.

## What this design doesn't do

- It doesn't detect equivalent mutants beyond the ones the source text proves.
- It doesn't use a value's class: `MethodExpression` and the operator mutators match by name and syntax alone.
- It has no mutation levels: every mutator runs.
- It doesn't ignore a site by default: logger calls and code between `# :nocov:` comments get mutants.
- It doesn't mutate symbols, numbers other than their sign, `nil`, or `case`/`in` patterns.
