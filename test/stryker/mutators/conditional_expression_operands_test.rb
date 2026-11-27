# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/conditional_expression"
require_relative("../../support/mutator_case")

# Checks the pairs of ConditionalExpression for comparisons and logical
# operators outside a condition, and for their operands, from its section of
# docs/contributors/design/mutators.md.
class ConditionalExpressionOperandsTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::ConditionalExpression
  end

  def test_a_comparison_becomes_true_and_false
    assert_equal(["ok = true", "ok = false"], mutated("ok = a == b"))
  end

  def test_each_comparison_operator_becomes_true_and_false
    sources = ["a == b", "a != b", "a < b", "a <= b", "a > b", "a >= b"]

    assert_equal(%w[true false] * 6, sources.flat_map { |source| replacements("ok = #{source}") })
  end

  def test_a_logical_operator_becomes_true_and_false
    assert_equal(%w[true false true false], replacements("ok = a && b\nok = a || b\n"))
  end

  def test_the_keyword_logical_operators_become_true_and_false
    assert_equal(%w[true false true false], replacements("ok = (a and b)\nok = (a or b)\n"))
  end

  def test_a_comparison_as_an_argument_becomes_true_and_false
    assert_equal(["f(true)", "f(false)"], mutated("f(a == b)"))
  end

  def test_a_comparison_as_a_return_value_becomes_true_and_false
    assert_equal(["return true", "return false"], mutated("return a < b"))
  end

  def test_a_comparison_in_parentheses_under_a_not_becomes_true_and_false
    assert_equal(["!(true)", "!(false)"], mutated("!(a == b)"))
  end

  def test_a_comparison_in_the_body_of_a_branch_becomes_true_and_false
    assert_equal(
      ["if true then a == b end", "if false then a == b end", "if c then true end", "if c then false end"],
      mutated("if c then a == b end")
    )
  end

  def test_a_comparison_that_is_a_condition_gets_one_pair_and_not_two
    assert_equal(2, edits("if a == b then x end").size)
  end

  def test_a_comparison_operand_of_or_becomes_only_false
    assert_equal(["x = true", "x = false", "x = a || false"], mutated("x = a || b == c"))
  end

  def test_a_comparison_operand_of_the_keyword_or_becomes_only_false
    assert_equal(["x = (true)", "x = (false)", "x = (false or b)"], mutated("x = (a == 1 or b)"))
  end

  def test_a_comparison_operand_of_and_becomes_only_true
    assert_equal(["x = (true)", "x = (false)", "x = (true && b)"], mutated("x = (a == 1 && b)"))
  end

  def test_a_comparison_operand_of_the_keyword_and_becomes_only_true
    assert_equal(["x = (true)", "x = (false)", "x = (a and true)"], mutated("x = (a and b == 1)"))
  end

  def test_a_logical_operand_of_or_becomes_only_false
    assert_equal(["x = (true)", "x = (false)", "x = (a || false)"], mutated("x = (a || b && c)"))
  end

  def test_a_logical_operand_of_and_becomes_only_true
    assert_equal(["x = (true)", "x = (false)", "x = ((true) && c)"], mutated("x = ((a || b) && c)"))
  end

  def test_an_operand_that_is_not_a_comparison_or_a_logical_operator_gets_no_mutant
    assert_equal(["x = (true)", "x = (false)"], mutated("x = (a || b.c)"))
  end

  def test_the_operands_and_the_whole_condition_each_make_a_mutant_in_the_order_of_the_tree
    assert_equal(
      ["if true then x end", "if false then x end", "if true && b then x end"],
      mutated("if a == 1 && b then x end")
    )
  end

  def test_an_operand_in_parentheses_is_the_operand_of_the_operator
    assert_equal(["x = (true)", "x = (false)", "x = (a || (false))"], mutated("x = (a || (b == c))"))
  end
end
