# frozen_string_literal: true

require_relative("../test_helper")
require "fileutils"
require "stryker/config"
require "stryker/instrumentation"
require "tmpdir"

# Checks that the stages that find mutants and instrument them report the
# mutants of an excluded mutator as Ignored, with no switch.
class InstrumentationExcludedTest < Minitest::Test
  # Two mutators of the catalog, so that the mutants stay the same as the
  # catalog grows.
  OPERATORS = [Stryker::Mutators::ArithmeticOperator, Stryker::Mutators::BooleanLiteral].freeze
  private_constant(:OPERATORS)

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

  def ids_and_names(mutants)
    mutants.map { |mutant| [mutant.id, mutant.mutator_name] }
  end

  def test_an_excluded_mutators_mutants_get_no_switch_and_the_status_ignored_with_the_reason
    found = instrumented(excluded_mutations: ["BooleanLiteral"])

    assert_equal([[1, "ArithmeticOperator"]], ids_and_names(found.mutants))
    assert_equal(
      [[2, "Ignored", 'Ignored because of excluded mutation "BooleanLiteral"']],
      found.unrun.map { |result| [result.mutant.id, result.status, result.status_reason] }
    )
  end

  def test_an_excluded_mutators_file_keeps_its_original_source
    found = instrumented(excluded_mutations: ["BooleanLiteral"])

    assert_equal("def on = true\n", found.sources[File.join(@root, "lib/flag.rb")])
  end

  def test_the_ignored_mutants_of_a_file_use_ids_of_the_run_too
    write("lib/a_flag.rb", "def off = false\n")
    found = instrumented(%w[lib/a_flag.rb lib/cart.rb], excluded_mutations: ["BooleanLiteral"])

    assert_equal([2], found.mutants.map(&:id))
    assert_equal([1], found.unrun.map { |result| result.mutant.id })
  end

  def test_an_excluded_mutators_mutant_does_not_keep_a_call_from_being_removed
    write("lib/notice.rb", "def notify(log)\n  log.push(\"saved\")\n  log\nend\n")
    mutators = [Stryker::Mutators::CallExpression, Stryker::Mutators::StringLiteral]
    kept = instrumented(["lib/notice.rb"], mutators:)
    excluded = instrumented(["lib/notice.rb"], mutators:, excluded_mutations: ["StringLiteral"])

    assert_equal(%w[StringLiteral], kept.mutants.map(&:mutator_name))
    assert_equal(%w[CallExpression], excluded.mutants.map(&:mutator_name))
    assert_equal(%w[StringLiteral], excluded.unrun.map { |result| result.mutant.mutator_name })
  end
end
