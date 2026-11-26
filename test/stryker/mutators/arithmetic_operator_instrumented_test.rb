# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/arithmetic_operator"
require_relative("../../support/mutator_sites")

# Runs the mutants of ArithmeticOperator through the instrumenter and checks
# that the program behaves as the original with no mutant active, and as the
# plain mutant with each mutant active.
class ArithmeticOperatorInstrumentedTest < Minitest::Test
  include SiteCase
  include MutatorSites

  def mutator
    Stryker::Mutators::ArithmeticOperator
  end

  def test_every_pair_of_the_table
    source = "a = 7\nb = 3\np(a + b)\np(a - b)\np(a * b)\np(a / b)\np(a % b)\n"

    assert_equal(5, assert_mutator_site(source, mutator, holder: Prism::CallNode).size)
  end

  def test_an_operator_inside_another_operators_operand
    # The plain mutant of the inner one is a + (b - c), as its switch runs it.
    source = "a = 0.1\nb = 0.2\nc = 0.3\np(a + b * c)\n"

    assert_equal(2, assert_mutator_site(source, mutator, holder: Prism::CallNode).size)
  end

  def test_an_operator_across_lines
    source = "a = 7\nb = 3\np(a +\n  b)\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::CallNode).size)
  end

  def test_an_operator_after_a_string_that_is_left_alone
    source = "a = 7\nb = 3\nputs '=' * 3, a + b\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::CallNode).size)
  end
end
