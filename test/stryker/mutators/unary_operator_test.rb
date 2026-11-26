# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/unary_operator"
require_relative("../../support/mutator_case")

# Checks the pairs of UnaryOperator and the nodes it makes no mutant of, from
# its section of docs/design/mutators.md.
class UnaryOperatorTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::UnaryOperator
  end

  def test_is_named_for_the_report
    assert_equal("UnaryOperator", mutator.name)
  end

  def test_minus_becomes_its_operand
    assert_equal(["a"], replacements("-a"))
  end

  def test_plus_becomes_minus
    assert_equal(["-a"], replacements("+a"))
  end

  def test_complement_becomes_its_operand
    assert_equal(["a"], replacements("~a"))
  end

  def test_the_edit_covers_the_whole_call
    edit = edits("ok = -a\n").first

    assert_equal([5, 7, "a"], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_the_mutant_is_the_whole_file_with_the_operator_changed
    assert_equal(["ok = -a\n"], mutated("ok = +a\n"))
  end

  def test_keeps_the_text_between_the_operator_and_the_operand_of_a_plus
    assert_equal(["- a"], replacements("+ a"))
  end

  def test_a_minus_with_a_space_becomes_its_operand
    assert_equal(["a"], replacements("- a"))
  end

  def test_minus_becomes_a_whole_operand
    operands = ["-a ** 2", "-a.b", "-(a + b)", "-réponse"].flat_map { |source| replacements(source) }

    assert_equal(["a ** 2", "a.b", "(a + b)", "réponse"], operands)
  end

  def test_a_minus_before_a_number_with_a_space_is_a_call_and_becomes_its_operand
    assert_equal(["1"], replacements("- 1"))
  end

  def test_makes_a_mutant_for_each_sign_in_an_expression_in_the_order_of_the_tree
    assert_equal(["-(-a)", "a"], replacements("+(-a)"))
  end

  def test_a_negative_integer_loses_its_sign
    assert_equal(%w[1 1_000 0x10], ["-1", "-1_000", "-0x10"].flat_map { |source| replacements(source) })
  end

  def test_a_negative_float_loses_its_sign
    assert_equal(["2.5"], replacements("-2.5"))
  end

  def test_a_negative_rational_loses_its_sign
    assert_equal(["1r"], replacements("-1r"))
  end

  def test_a_negative_imaginary_number_loses_its_sign
    assert_equal(%w[2i 1ri], ["-2i", "-1ri"].flat_map { |source| replacements(source) })
  end

  def test_the_number_inside_a_negative_imaginary_literal_gets_no_mutant_of_its_own
    assert_equal(["2i"], replacements("-2i"))
  end

  def test_the_edit_of_a_negative_literal_covers_the_whole_literal
    edit = edits("ok = -1.5\n").first

    assert_equal([5, 9, "1.5"], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_a_negative_literal_that_is_a_receiver_loses_its_sign
    assert_equal(["1"], replacements("-1.abs"))
  end

  def test_makes_no_mutant_of_a_negative_zero
    assert_empty(edits("-0\n-0.0\n-0r\n-0i\n-0x0\n"))
  end

  def test_makes_no_mutant_of_a_positive_literal
    assert_empty(edits("1\n+1\n2.5\n+2.5\n1r\n"))
  end

  def test_makes_no_mutant_of_a_node_that_is_not_a_unary_operator
    assert_empty(edits("a = 1\n[1, 2]\nx if y\na - b\na + b\n!a\n"))
  end

  def test_makes_no_mutant_of_an_operator_written_as_a_method_call
    assert_empty(edits("a.-@\na&.+@\na.~\n"))
  end

  def test_makes_no_mutant_of_a_minus_or_a_plus_on_a_string_literal
    sources = ["-'draft'", "+'draft'", "-\"a\#{b}\"", "-<<~TEXT\n  a\nTEXT\n", "-`ls`", "-`ls \#{b}`"]

    assert_empty(sources.flat_map { |source| edits(source) })
  end

  def test_makes_a_mutant_of_a_complement_on_a_string_literal
    assert_equal(["'a'"], replacements("~'a'"))
  end

  def test_makes_a_mutant_of_a_minus_on_a_parenthesized_string
    assert_equal(["('a')"], replacements("-('a')"))
  end
end
