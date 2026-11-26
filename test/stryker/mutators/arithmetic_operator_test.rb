# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/arithmetic_operator"
require_relative("../../support/mutator_case")

# Checks the pairs of ArithmeticOperator and the calls it makes no mutant of,
# from its section of docs/design/mutators.md.
class ArithmeticOperatorTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::ArithmeticOperator
  end

  def test_is_named_for_the_report
    assert_equal("ArithmeticOperator", mutator.name)
  end

  def test_plus_becomes_minus
    assert_equal(["a - b"], replacements("a + b"))
  end

  def test_minus_becomes_plus
    assert_equal(["a + b"], replacements("a - b"))
  end

  def test_times_becomes_divided_by
    assert_equal(["a / b"], replacements("a * b"))
  end

  def test_divided_by_becomes_times
    assert_equal(["a * b"], replacements("a / b"))
  end

  def test_modulo_becomes_times
    assert_equal(["a * b"], replacements("a % b"))
  end

  def test_the_edit_covers_the_whole_call
    edit = edits("total = a + b\n").first

    assert_equal([8, 13, "a - b"], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_the_edit_counts_bytes
    edit = edits("é = a + b\n").first

    assert_equal([5, 10], [edit.start_offset, edit.end_offset])
  end

  def test_the_mutant_is_the_whole_file_with_the_operator_changed
    assert_equal(["total = a - b\n"], mutated("total = a + b\n"))
  end

  def test_keeps_the_text_between_the_operands
    spaced = ["a+b", "a  +  b", "a +\n  b"].flat_map { |source| replacements(source) }

    assert_equal(["a-b", "a  -  b", "a -\n  b"], spaced)
  end

  def test_keeps_a_multibyte_operand_whole
    assert_equal(["réponse - b"], replacements("réponse + b"))
  end

  def test_keeps_the_operands_whole
    assert_equal(["f(a, 1) - items[2].size"], replacements("f(a, 1) + items[2].size"))
  end

  def test_makes_a_mutant_for_each_operator_in_an_expression_in_the_order_of_the_tree
    assert_equal(["a - b * c", "b / c"], replacements("a + b * c"))
  end

  def test_makes_a_mutant_of_an_operator_whose_operand_is_a_unary_minus
    assert_equal(["a + -b"], replacements("a - -b"))
  end

  def test_makes_no_mutant_of_a_node_that_is_not_a_call
    assert_empty(edits("a = 1\n[1, 2]\nx if y\n"))
  end

  def test_makes_no_mutant_of_a_call_that_is_not_an_arithmetic_operator
    assert_empty(edits("a ** b\na << b\na >> b\na & b\na < b\na.size\nsize(a)"))
  end

  def test_makes_no_mutant_of_an_operator_written_as_a_method_call
    assert_empty(edits("a.+(b)\na&.+(b)\nself.+(b)\na.-(b)"))
  end

  def test_makes_no_mutant_of_a_unary_operator
    assert_empty(edits("-a\n+a"))
  end

  def test_makes_no_mutant_when_the_right_operand_is_a_string_literal
    assert_empty(edits("names * ', '\nx + 'a'\nx + \"a\#{y}\"\nx + <<~TEXT\n  a\nTEXT\nx + `ls`\n"))
  end

  def test_makes_no_mutant_when_the_left_operand_is_a_string_literal
    assert_empty(edits("'=' * 40\n\"%.2f\" % total\n\"a\#{y}\" + x\n`ls` + x\n"))
  end

  def test_makes_no_mutant_when_both_operands_are_string_literals
    assert_empty(edits("'a' + 'b'"))
  end

  def test_makes_a_mutant_when_an_operand_only_holds_a_string
    assert_equal(['("a") / 3', 'x - "a".size'], replacements('("a") * 3; x + "a".size'))
  end

  def test_makes_a_mutant_when_an_operand_is_a_symbol_or_a_number
    assert_equal([":a - 1", "1 / 2.5"], replacements(":a + 1; 1 * 2.5"))
  end
end
