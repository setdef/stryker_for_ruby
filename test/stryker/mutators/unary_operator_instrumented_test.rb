# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/unary_operator"
require_relative("../../support/mutator_sites")

# Runs the mutants of UnaryOperator through the instrumenter and checks that
# the program behaves as the original with no mutant active, and as the plain
# mutant with each mutant active.
class UnaryOperatorInstrumentedTest < Minitest::Test
  include SiteCase
  include MutatorSites

  def mutator
    Stryker::Mutators::UnaryOperator
  end

  def test_minus_plus_and_complement
    source = "a = 5\np(-a)\np(+a)\np(~a)\n"

    assert_equal(3, assert_mutator_site(source, mutator, holder: Prism::CallNode).size)
  end

  def test_minus_on_a_power
    # The mutant is a ** 2, which the switch runs in parentheses.
    source = "a = 3\np(-a ** 2)\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::CallNode).size)
  end

  def test_a_minus_with_a_space_before_a_number
    source = "p(- 1)\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::CallNode).size)
  end

  def test_a_negative_integer
    assert_equal(1, assert_mutator_site("p(-1)\n", mutator, holder: Prism::IntegerNode).size)
  end

  def test_a_negative_float
    assert_equal(1, assert_mutator_site("p(-2.5)\n", mutator, holder: Prism::FloatNode).size)
  end

  def test_a_negative_rational
    assert_equal(1, assert_mutator_site("p(-3r)\n", mutator, holder: Prism::RationalNode).size)
  end

  def test_a_negative_imaginary_number
    assert_equal(1, assert_mutator_site("p(-2i)\n", mutator, holder: Prism::ImaginaryNode).size)
  end

  def test_a_negative_integer_that_is_a_receiver
    assert_equal(1, assert_mutator_site("p(-1.succ)\n", mutator, holder: Prism::IntegerNode).size)
  end

  def test_a_positive_integer
    assert_equal(1, assert_mutator_site("p(+1)\n", mutator, holder: Prism::IntegerNode).size)
  end

  def test_a_positive_float
    assert_equal(1, assert_mutator_site("p(+2.5)\n", mutator, holder: Prism::FloatNode).size)
  end

  def test_a_positive_rational
    assert_equal(1, assert_mutator_site("p(+3r)\n", mutator, holder: Prism::RationalNode).size)
  end

  def test_a_positive_imaginary_number
    assert_equal(1, assert_mutator_site("p(+2i)\n", mutator, holder: Prism::ImaginaryNode).size)
  end

  def test_a_positive_integer_that_is_a_receiver
    assert_equal(1, assert_mutator_site("p(+1.succ)\n", mutator, holder: Prism::IntegerNode).size)
  end

  def test_a_unary_operator_across_lines
    source = "a = 5\np(-\n  a)\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::CallNode).size)
  end

  def test_a_minus_on_a_string_is_left_alone
    source = "a = 5\np((-'draft').frozen?, -a)\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::CallNode).size)
  end
end
