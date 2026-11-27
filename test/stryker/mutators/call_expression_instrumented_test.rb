# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/call_expression"
require_relative("../../support/mutator_sites")

# Runs the mutants of CallExpression through the instrumenter and checks that
# the program behaves as the original with no mutant active, and as the plain
# mutant with each mutant active.
class CallExpressionInstrumentedTest < Minitest::Test
  include SiteCase
  include MutatorSites

  def mutator
    Stryker::Mutators::CallExpression
  end

  # Each program ends with a call to p, which is a statement and gets a
  # mutant of its own, counted in +count+.
  def assert_sites(count, source, holder: Prism::CallNode)
    assert_equal(count, assert_mutator_site(source, mutator, holder:).size)
  end

  def test_a_call_in_a_method
    assert_sites(3, "def save(log)\n  log.push(:checked)\n  log.push(:saved)\n  log\nend\np save([])\n")
  end

  def test_a_call_in_a_block_under_a_modifier_if
    assert_sites(2, "seen = []\n[1, 2].each { |n| seen.push(n) if n > 1 }\np seen\n")
  end

  def test_a_call_with_arguments_written_without_parentheses
    assert_sites(2, "log = []\nlog.push :saved\np log\n")
  end

  def test_an_operator_call
    assert_sites(2, "log = []\nlog << :saved\np log\n")
  end

  def test_a_raise
    assert_sites(2, "def check\n  raise ArgumentError\nrescue ArgumentError\n  :raised\nend\np check\n")
  end

  def test_a_call_with_safe_navigation
    assert_sites(2, "log = []\nlog&.push(:saved)\np log\n")
  end

  def test_a_call_whose_argument_is_a_heredoc
    assert_sites(2, "log = []\nlog.push(<<~A)\n  saved\nA\np log\n")
  end

  def test_a_call_in_a_class_body
    assert_sites(2, "class Order\n  attr_accessor :total\nend\np Order.method_defined?(:total)\n")
  end
end
