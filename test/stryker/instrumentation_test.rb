# frozen_string_literal: true

require_relative("../support/fake_mutator")
require_relative("../test_helper")
require "fileutils"
require "stryker/config"
require "stryker/edit"
require "stryker/instrumentation"
require "tmpdir"

# Checks the stages that parse each file, find its mutants, and instrument
# it, in a project of its own.
class InstrumentationTest < Minitest::Test
  # Makes a mutant of every `+` that the instrumenter can't parse.
  BROKEN = FakeMutator.new("ArithmeticOperator") do |node, _ancestors|
    next [] unless node.is_a?(Prism::CallNode) && node.name == :+

    [Stryker::Edit.over(node.location, "a +")]
  end
  # Makes a mutant of every regexp literal whose text has no form on one line.
  MULTILINE = FakeMutator.new("RegexLiteral") do |node, _ancestors|
    node.is_a?(Prism::RegularExpressionNode) ? [Stryker::Edit.over(node.location, "/c\nb/x")] : []
  end
  # Two mutators of the catalog, so that the mutants stay the same as the
  # catalog grows.
  OPERATORS = [Stryker::Mutators::ArithmeticOperator, Stryker::Mutators::BooleanLiteral].freeze
  private_constant(:BROKEN, :MULTILINE, :OPERATORS)

  def setup
    @root = Dir.mktmpdir("stryker-instrumentation-")
    write("lib/cart.rb", "def total(a, b) = a + b\n")
    write("lib/flag.rb", "def on = true\n")
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def write(name, source)
    path = File.join(@root, name)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, source)
  end

  def instrumented(paths = %w[lib/cart.rb lib/flag.rb], mutators: OPERATORS, **)
    config = Stryker::Config.new(mutate: ["lib/**/*.rb"], test_runner: "minitest", concurrency: 1, **)
    Stryker::Instrumentation.new(@root, config, mutators).call(paths)
  end

  def test_each_mutant_has_an_id_of_its_own_across_the_files_and_names_its_file_from_the_root
    mutants = instrumented.mutants

    assert_equal(
      [[1, "lib/cart.rb", "a - b"], [2, "lib/flag.rb", "false"]],
      mutants.map { |mutant| [mutant.id, mutant.file, mutant.replacement] }
    )
  end

  def test_each_file_has_its_instrumented_source_under_its_absolute_path
    sources = instrumented.sources

    assert_equal([File.join(@root, "lib/cart.rb"), File.join(@root, "lib/flag.rb")], sources.keys)
    assert_includes(sources[File.join(@root, "lib/flag.rb")], "::Stryker::Active.id == 2 ? (false)")
  end

  def test_an_excluded_mutator_makes_no_mutant
    found = instrumented(excluded_mutations: ["BooleanLiteral"])

    assert_equal([[1, "ArithmeticOperator"]], found.mutants.map { |mutant| [mutant.id, mutant.mutator_name] })
    assert_equal("def on = true\n", found.sources[File.join(@root, "lib/flag.rb")])
  end

  def test_an_excluded_mutators_mutant_does_not_keep_a_call_from_being_removed
    write("lib/notice.rb", "def notify(log)\n  log.push(\"saved\")\n  log\nend\n")
    mutators = [Stryker::Mutators::CallExpression, Stryker::Mutators::StringLiteral]
    kept = instrumented(["lib/notice.rb"], mutators:).mutants
    excluded = instrumented(["lib/notice.rb"], mutators:, excluded_mutations: ["StringLiteral"]).mutants

    assert_equal([%w[StringLiteral], %w[CallExpression]], [kept, excluded].map { |found| found.map(&:mutator_name) })
  end

  def test_a_mutant_that_is_not_valid_ruby_gets_no_switch_and_the_status_compile_error
    found = instrumented(["lib/cart.rb"], mutators: [BROKEN])

    assert_empty(found.mutants)
    assert_equal(
      [[1, "CompileError", nil]],
      found.unrun.map { |result| [result.mutant.id, result.status, result.tests_completed] }
    )
    assert_equal("def total(a, b) = a + b\n", found.sources.values.first)
  end

  def test_a_mutant_with_no_place_for_a_switch_gets_no_switch_and_the_status_ignored_with_its_reason
    write("lib/boot.rb", "BEGIN { $b = 1 + 2 }\n")
    found = instrumented(["lib/boot.rb"])

    assert_empty(found.mutants)
    assert_equal(
      [[1, "Ignored", "The site can't hold a switch, so no test can run with this mutant."]],
      found.unrun.map { |result| [result.mutant.id, result.status, result.status_reason] }
    )
  end

  def test_a_mutant_with_no_one_line_form_gets_no_switch_and_the_status_ignored_with_its_reason
    write("lib/pattern.rb", "def pattern = /a\nb/x\n")
    found = instrumented(["lib/pattern.rb"], mutators: [MULTILINE])

    assert_equal(
      [[1, "Ignored", "The mutant has no form on one line, so no test can run with this mutant."]],
      found.unrun.map { |result| [result.mutant.id, result.status, result.status_reason] }
    )
  end

  def test_an_erb_template_stops_the_run_before_any_file_is_instrumented
    write("app/views/cart.html.erb", "<%= 1 + 2 %>\n")

    error = assert_raises(Stryker::UnsupportedError) { instrumented(%w[lib/cart.rb app/views/cart.html.erb]) }

    assert_equal(
      "Stryker (for Ruby) doesn't mutate ERB templates, and the mutate option selects app/views/cart.html.erb. " \
        "Leave templates out with a pattern such as \"!**/*.erb\".",
      error.message
    )
  end

  def test_no_file_gives_no_mutant_and_no_source
    found = instrumented([])

    assert_equal([[], {}, []], [found.mutants, found.sources, found.unrun])
  end
end
