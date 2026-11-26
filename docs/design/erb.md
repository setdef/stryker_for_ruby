# ERB templates

This page specifies how **Stryker (for Ruby)** puts mutants into ERB templates and how the instrumented text gets into a process. It covers how the extractor finds the Ruby in a template, where mutants may go, how Rails and the Ruby libraries that render ERB receive the instrumented text, the cases where a template loads uninstrumented, and what the dry run reports about them. ERB is in scope inside Rails and outside it, so the page covers a template that Rails renders and one that stdlib `ERB`, Erubi, or Tilt renders. The reasons for compiling every mutant into the code once and switching it on at run time are in [ADR 0001](../decisions/0001-mutants-are-compiled-into-the-code-once-and-switched-on-at-run-time.md), and the reasons Erubi loads only in the orchestrator are in [ADR 0003](../decisions/0003-the-processes-that-load-the-projects-code-load-only-stryker-for-rubys-runtime-which-depends-on-nothing-outside-the-standard-library.md). The terms are defined in [Loading and isolation](loading-and-isolation.md#terms).

The decisions on this page, and the probes behind them, are in [#9](https://github.com/setdef/stryker_for_ruby/issues/9).

## Why templates need another route

An ERB template isn't a Ruby file. Ruby never compiles it from disk, so the [`load_iseq` hook](loading-and-isolation.md#the-load_iseq-hook) never sees it. Stdlib `ERB` and Erubi take the template's text, not a file, and neither calls `load_iseq` or gives a hook the template's path. Rails reads the file and hands the text to a template handler.

So an ERB template needs three things that a Ruby file gets from the instrumenter and the hook:

1. A way to find the Ruby in the text, with every byte at its offset in the template ([Finding the Ruby](#finding-the-ruby)).
2. Mutants only where a switch can go ([Where mutants go](#where-mutants-go)).
3. A way to hand the instrumented text to whatever renders the template ([Loading the instrumented text](#loading-the-instrumented-text)).

## Finding the Ruby

The instrumenter runs an extractor on each ERB template in `mutate`. It uses the tag regexp of Erubi, the public constant `Erubi::Engine::DEFAULT_REGEXP`:

```text
/<%(={1,2}|-|\#|%)?(.*?)([-=])?%>([ \t]*\r?\n)?/m
```

Erubi is pure Ruby with no dependencies, and ActionView 8.1 compiles every ERB template through it with this regexp, so the extractor finds the tags that Rails compiles. It loads Erubi only in the orchestrator ([ADR 0003](../decisions/0003-the-processes-that-load-the-projects-code-load-only-stryker-for-rubys-runtime-which-depends-on-nothing-outside-the-standard-library.md)), and needs no compiler, so it runs the same on every system.

### The extraction rules

The extractor applies the regexp to the template with `String#scan`. Each match has four groups: the indicator (`=`, `==`, `-`, `#`, or `%`, which is optional), the tag's code, the tail character (`-` or `=`, which is optional), and the whitespace and newline after the tag. It builds the extracted text byte by byte:

1. Start with a copy of the template in which every byte except CR and LF is a space. The copy has the template's length and every newline at its template offset.
2. For each match whose indicator is `=`, `==`, `-`, or absent, copy the bytes of the code, taken from `MatchData#byteoffset(2)`, to the same offsets in the copy.
3. Put `;` on the byte that follows the code. That byte is always the first byte of the tag's end (`-`, `=`, or the `%` of `%>`), so the `;` never overwrites a CR or an LF. The `;` ends each tag's code as a statement, the way Erubi's compiled output does, so the code of two tags can't run together.
4. Leave a tag with the indicator `#` (a comment tag) or `%` (`<%%`, which Erubi renders as the text `<%`) blank. It holds no code.
5. Leave a tag blank when its code is a one-line `#` comment: spaces and tabs, then `#`, then no CR or LF. Such a tag holds no code either.

The extracted text is what Prism parses. Its byte offsets are the template's byte offsets, so a Prism location in the extracted text is a location in the template. This template, with a space shown as `.`:

```erb
<ul>
<% @items.each do |item| %>
  <li><%= link_to item.name, item %></li>
<% end -%>
<%# note %>
<% # one-line comment %>
<%% literal %>
</ul>
```

gives this extracted text:

```text
....
...@items.each.do.|item|.;.
..........link_to.item.name,.item.;......
...end.;..
...........
........................
..............
.....
```

The first tag's code starts at the space after `<%`, and the `;` takes the place of its `%`. In the fourth line, the `-` of `-%>` becomes the `;`.

Where Erubi's regexp finds a tag that stdlib `ERB` wouldn't, the extractor follows Erubi: in the degenerate templates that probes tried (`<%%>` followed by another tag, empty tags, and tags left unterminated), it finds the tags that Erubi compiles. Whether stdlib `ERB` agrees is a separate check ([Stdlib ERB's trim modes](#stdlib-erbs-trim-modes)).

### Parsing

Prism parses the extracted text with `partial_script: true`. A template is not a whole script: a layout's `yield` is a syntax error in a script and valid in a partial script, as Prism 2.1.0 shows.

```ruby
# false
Prism.parse("yield;").success?
# true
Prism.parse("yield;", partial_script: true).success?
```

A block or an `if` that spans several tags parses as one piece, because the text between the tags is blank.

A probe ran the extractor on 58 templates: 19 real ones (the Rails scaffold views and the application layout, multi-line tags, `<%==`, `<%-` and `-%>`, `<%#`, `<%%`, blocks and `if` chains split across tags, `form_with ... do |f|`, multibyte text, and CRLF line endings) and 39 edge cases. The extracted text was the same on Windows with Ruby 3.4.13 and on Ruby 3.3, 3.4, 4.0, and 4.1-dev. On a 100 KB template, the extractor took 36 ms on macOS, which is paid once per run.

A template that Prism can't parse gets no mutant, and the run reports it by name. One kind can't parse at all: a heredoc whose body is outside its tag. Erubi's compiled output for such a template doesn't parse either.

## Where mutants go

A mutant goes only at a site inside one tag: a site whose whole byte range lies in the code of a single tag. A switch never wraps a node that spans tags, because its mutant branch would have to hold the HTML between the tags. The mutators reach such a node through its parts that lie inside a tag: a block call's receiver and method, or an `if`'s condition.

In this template, the `if` spans three tags, so it gets no switch. Its condition lies in the first tag, and `total + shipping` lies in the second, so each takes a switch:

```erb
<% if cart_items.any? %>
  Total: <%= total + shipping %>
<% end %>
```

With mutant 1 replacing the condition by `true`, and mutant 2 replacing `+` by `-`, the instrumented text is:

```erb
<% if (::Stryker::Active.id == 1 ? (true) : (::Stryker::Active.hit(1); (cart_items.any?))) %>
  Total: <%= (::Stryker::Active.id == 2 ? (total - shipping) : (::Stryker::Active.hit(2); (total + shipping))) %>
<% end %>
```

The instrumenter splices each switch into a copy of the template, at the offset where Prism found the site. The text outside the switches stays as it was, byte for byte, and the `;` that the extractor adds is never part of it. The switch has the form that [Mutant placement](mutant-placement.md#the-switch) specifies, and it keeps every line where it was ([Every line stays where it was](mutant-placement.md#every-line-stays-where-it-was)). Rendered with no mutant active, the instrumented text gives the original's output. With each mutant active, it gives the plain mutant's output: the template with only that change made. That held for an operator, an `if` condition, a string literal in `link_to`, the receiver and the method of a block call that spans tags, and a method argument. An exception raised in the template reports the template's file and line.

Some Erubi engines compile an output tag into a statement that takes one expression. `Erubi::CaptureBlockEngine` expands `<%= code %>` to `_buf <<= code`, so the text inside an output tag has to be one parenthesized expression. A switch already is one.

## Loading the instrumented text

The instrumented text of every ERB template is in the cache, as every instrumented file is ([The cache](loading-and-isolation.md#the-cache)), and the runtime holds a lookup table from a template to its text. A project process patches a library only when the project itself has loaded that library, so the runtime never loads ActionView, Erubi, or Tilt. Each hook below passes the instrumented text on to the code that was going to receive the original, so nothing is changed on disk.

| Where the template is rendered | Hook | Key |
| - | - | - |
| Rails (ActionView) | A wrapper around the handler registered for `.erb` | `template.identifier` |
| Stdlib `ERB` | A prepend on `ERB#initialize` | The text's bytes |
| Erubi | A prepend on `Erubi::Engine#initialize` | The text's bytes |
| Tilt | A prepend on `Tilt::Template#read_template_file` | The template's path |

### Rails

ActionView compiles a template by calling the handler registered for its extension: `call(template, source)` returns the Ruby source to compile. The runtime wraps whatever handler is registered for `.erb`, which is a public API (`ActionView::Template.register_template_handler :erb`). A project or gem that replaced Rails' handler keeps its replacement. The wrapper finds the instrumented text by `template.identifier`, and passes it to the wrapped handler in place of `source`. It installs only in a project process where ActionView is loaded.

Four hooks served the instrumented text to ActionView, and none changed a file. Each passed 34 of 34 tests (controller, integration, view, and helper tests, over partials, collections, and layouts, checking that `template.identifier`, `virtual_path`, error lines, and ActionView's compiled-template cache were unchanged):

| Hook | Rails surface it depends on |
| - | - |
| Wrap the ERB template handler (`register_template_handler :erb`, `call(template, source)`) | public API |
| A `FileSystemResolver` subclass overriding `source_for_template` | a private method |
| `prepend` on `Template::Sources::File#to_s` | an internal class and its instance variable |
| `prepend` on `Template#source` | an undocumented method and an instance variable |

The wrapper is the one this page specifies. The other three lost because each depends on a private or internal part of Rails.

A cost of the wrapper: `Template#source` still returns the original text, so Rails' error page shows the original line. That page shows the developer's file.

A template that ActionView renders passes through `Erubi::Engine#initialize` too. Because the wrapper hands Erubi the instrumented text, the Erubi prepend looks up text that isn't in its table and passes it on unchanged, so no template is instrumented twice. The wrapper also covers what a lookup by the file's bytes would miss: ActionView removes an `<%# encoding: %>` tag and transcodes the text before Erubi sees it.

### Stdlib `ERB`, Erubi, and Tilt

These libraries take text, so the runtime swaps the text at the constructor. A module prepended to `ERB#initialize` and another prepended to `Erubi::Engine#initialize` each look up the incoming text. When the text is a key in the table, the module passes the instrumented text to `super`. Otherwise it passes the text it received. Both render the same output as the original in all 14 forms that probes tried, on Linux, macOS, and Windows, on Ruby 3.3, 3.4, 4.0, and 4.1-dev:

- `ERB.new(...).result(binding)`, with and without `trim_mode: "-"`
- `result_with_hash`, `def_method`, `def_class`, and `ERB::DefMethod.def_erb_method`
- Erubi's `src` passed to `eval`, `CaptureBlockEngine`, and `CaptureEndEngine`
- `Tilt.new(path)`, `Tilt::ERBTemplate`, and `Tilt::ErubiTemplate`, each from a path and from a block

An exception raised in the template reports the template's line in every form that passes a filename.

The lookup took 0.5 to 0.8 ms per 1,000 calls on 1 KB templates, against 150 to 200 ms for `ERB.new` itself.

#### The prepends declare the exact parameter lists

Each prepend declares exactly the parameters of the method it wraps, in the installed version. The versions that probes tried:

| Method | Parameters |
| - | - |
| `ERB#initialize`, ERB 6.0.0 to 6.1.0 | `str`, `trim_mode: nil`, `eoutvar: "_erbout"` |
| `ERB#initialize`, ERB 4.0.3 (Ruby 3.3's) | `str`, `safe_level = NOT_GIVEN`, `legacy_trim_mode = NOT_GIVEN`, `legacy_eoutvar = NOT_GIVEN`, `trim_mode: nil`, `eoutvar: "_erbout"` |
| `Erubi::Engine#initialize`, Erubi 1.13.1 | `input`, `properties = {}` |
| `Tilt::Template#read_template_file`, Tilt 2.9.0 | none |

> [!WARNING]
> A prepend on `ERB#initialize` that declares `(str, *args, **kwargs)` breaks Tilt. Tilt reads `ERB.instance_method(:initialize).parameters` when its ERB template loads, and passes keyword arguments only when the list has a keyword parameter. A rest parameter and a keyword rest parameter (`*args`, `**kwargs`, or the anonymous `*` and `**`) are not keyword parameters, so Tilt falls back to positional arguments, and `ERB.new` raises `ArgumentError`. The error is raised the first time a Tilt template is made, and the template never renders.

In these sketches, `TEXTS` stands for the lookup table: a frozen Hash from a template's bytes to its instrumented text.

```ruby
# Wrong: this list has no keyword parameter, so Tilt passes `trim_mode` and
# `eoutvar` as positional arguments. On ERB 6.0.7, `ERB.new` then raises
# "wrong number of arguments (given 4, expected 1)".
module WrongErbInitialize
  # Swaps the text, and forwards every other argument.
  def initialize(str, *, **)
    super(TEXTS.fetch(str.b, str), *, **)
  end
end
```

```ruby
# Right: the same parameters as ERB 6.x.
ERB.prepend(
  Module.new do
    # Swaps the text, and forwards the keywords.
    def initialize(str, trim_mode: nil, eoutvar: "_erbout")
      super(TEXTS.fetch(str.b, str), trim_mode:, eoutvar:)
    end
  end
)
```

`TEXTS.fetch(str.b, str)` passes the instrumented text when `str` is a key, and `str` itself otherwise. With the right form, Tilt's `ERBTemplate` renders the swapped text.

#### The lookup keys on the text's bytes

What reaches a constructor depends on how the file was read:

- On macOS and Linux, every common way of reading a file passes the file's text unchanged.
- A binary read passes the same bytes in ASCII-8BIT.
- On Windows, a text-mode read turns CRLF into LF ([CRLF on Windows](#crlf-on-windows)).
- A `bom|utf-8` read strips the BOM.

So the lookup key is `String#b`, the bytes with no encoding, and nothing is normalized before the lookup. A lookup that normalized line endings or the BOM would map two files that differ only in those to one key, and serve one file's instrumented text for the other's template.

#### Identical texts get no mutants

Two files with identical text can't be told apart at the constructor: the key is the same, and no path is known there. Where two files in `mutate` have identical text and no path is known, neither gets mutants, and the run reports both by name instead of guessing.

Tilt has the path. `Tilt::Template#read_template_file` reads the file, and `file` is the path, so a prepend there looks up the path and returns the instrumented text of that file. In a probe, it served each of two files with identical text the text of that file. Tilt calls `read_template_file` only when no block gives the text, so a template made from a block reaches the constructor prepend, which keys on bytes.

```ruby
# Serves the instrumented text of the file at `file`, the path Tilt has.
Tilt::Template.prepend(
  Module.new do
    # Returns that text, or what Tilt reads from the file.
    def read_template_file
      PATH_TEXTS.fetch(file, nil) || super
    end
  end
)
```

In this sketch, `PATH_TEXTS` stands for a frozen Hash from a template's path to its instrumented text. Tilt then passes the text on to the same `ERB#initialize` or `Erubi::Engine#initialize` as any other, whose lookup misses, because the instrumented text isn't a key.

### CRLF on Windows

On Windows, a project that reads its templates in text mode turns each CRLF into LF before the text reaches a constructor. The text no longer matches the file's bytes, so the lookup misses, and the template loads uninstrumented. Files that use CRLF are the ones this affects. The dry run reports such a template ([What the dry run reports](#what-the-dry-run-reports)), so a miss from this cause is reported, never counted as `NoCoverage`.

### Stdlib ERB's trim modes

Stdlib `ERB` recognizes some tags differently from Erubi. The differences are the same in every ERB version that probes tried (4.0.3, 6.0.7, and 6.1.0). Most of them are templates that one engine can't compile. Three constructs are valid under both engines, yet the two find different code:

- `%%>` inside a tag
- `<%%>` followed by a tag
- a `%` line, when ERB's trim mode includes `%`

Trim modes `<>` and `>` find the same tags as no trim mode.

The extractor never guesses which code a tag holds. For a template that stdlib `ERB` renders, the orchestrator compiles the template with `ERB::Compiler` in each trim mode, and compares the tags ERB finds with the tags the extractor found. The `ERB#initialize` prepend serves the instrumented text only when the constructor's `trim_mode` is one in which the two sets of tags are identical. In any other trim mode, the template loads uninstrumented, and the dry run reports it.

The check covers the ERB constructor only. Erubi's tags are the extractor's by construction, so Erubi, ActionView, and the Tilt forms that use Erubi need no comparison.

## What the dry run reports

The dry run reports every ERB template in `mutate` that no hook served. A hook serves a template when the Rails wrapper or one of the prepends passes its instrumented text on. The dry run reports it the way the [loading check](loading-and-isolation.md#the-loading-check) reports a Ruby file, so a miss of any cause is reported instead of being counted as `NoCoverage`. The causes include these, and any other:

- a text-mode read on Windows ([CRLF on Windows](#crlf-on-windows))
- a read that strips the BOM
- a trim mode in which ERB's tags differ from the extractor's

## Hits and runtime mutants

Templates record hits only while they render. In a probe on a Rails app, none were recorded at boot, none at eager load, and none when a template compiled, and each test's hits landed in that test's bucket ([Hits](coverage.md#hits)).

So every ERB mutant is a runtime mutant: a template's switches run only while it renders. The plan gives each one a runtime run of the tests that reached it, and no ERB mutant gets a static run.

## Lookup tables are shareable

Every lookup table that the prepends and the wrapper hold is shareable (`Ractor.make_shareable`), so the prepends work inside Ractors.

## What this design doesn't do

- It doesn't change a template file, or write instrumented text into the project.
- It doesn't put a switch around a node that spans tags.
- It doesn't mutate a template that Prism can't parse. The run reports it by name.
- It doesn't mutate two files with identical text when no path is known. The run reports both by name.
- It doesn't normalize line endings or the BOM before a lookup.
- It doesn't serve instrumented text in a trim mode where ERB's tags differ from the extractor's.
- It doesn't change what `Template#source` returns, so Rails' error page shows the original line.
- It doesn't load Erubi in a project process. The prepends patch Erubi only when the project has loaded it.
- It doesn't instrument a template twice.
- It doesn't count a template that no hook served as `NoCoverage`.
