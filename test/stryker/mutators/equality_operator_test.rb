# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/equality_operator"
require_relative("../../support/mutator_case")

# Checks the pairs of EqualityOperator, the swap of <=>, and the calls it makes
# no mutant of, from its section of docs/design/mutators.md.
class EqualityOperatorTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::EqualityOperator
  end

  def test_is_named_for_the_report
    assert_equal("EqualityOperator", mutator.name)
  end

  def test_less_than_gets_the_boundary_and_then_the_negation
    assert_equal(["a <= b", "a >= b"], replacements("a < b"))
  end

  def test_less_than_or_equal_gets_the_boundary_and_then_the_negation
    assert_equal(["a < b", "a > b"], replacements("a <= b"))
  end

  def test_greater_than_gets_the_boundary_and_then_the_negation
    assert_equal(["a >= b", "a <= b"], replacements("a > b"))
  end

  def test_greater_than_or_equal_gets_the_boundary_and_then_the_negation
    assert_equal(["a > b", "a < b"], replacements("a >= b"))
  end

  def test_equal_becomes_not_equal
    assert_equal(["a != b"], replacements("a == b"))
  end

  def test_not_equal_becomes_equal
    assert_equal(["a == b"], replacements("a != b"))
  end

  def test_the_edit_covers_the_whole_call
    edit = edits("ok = a < b\n").first

    assert_equal([5, 10, "a <= b"], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_the_mutant_is_the_whole_file_with_the_operator_changed
    assert_equal(["ok = a <= b\n", "ok = a >= b\n"], mutated("ok = a < b\n"))
  end

  def test_keeps_the_text_between_the_operands
    spaced = ["a<b", "a  <  b", "a <\n  b"].map { |source| replacements(source).first }

    assert_equal(["a<=b", "a  <=  b", "a <=\n  b"], spaced)
  end

  def test_makes_a_mutant_for_each_comparison_in_an_expression_in_the_order_of_the_tree
    assert_equal(["a != b", "c <= d", "c >= d"], replacements("a == b && c < d"))
  end

  def test_makes_no_mutant_of_a_node_that_is_not_a_call
    assert_empty(edits("a = 1\n[1, 2]\nx if y\n"))
  end

  def test_makes_no_mutant_of_case_equality_matching_or_a_method_that_compares
    assert_empty(edits("a === b\na =~ b\na !~ b\na.eql?(b)\na.equal?(b)"))
  end

  def test_makes_no_mutant_of_an_operator_written_as_a_method_call
    assert_empty(edits("a.<(b)\na&.<=(b)\na.==(b)\na.<=>(b)\nself.!=(b)"))
  end

  def test_makes_no_mutant_of_the_check_that_a_file_is_the_script
    sources = ["__FILE__ == $0", "$0 == __FILE__", "__FILE__ == $PROGRAM_NAME", "$PROGRAM_NAME == __FILE__"]

    assert_empty(sources.flat_map { |source| edits(source) })
  end

  def test_makes_no_mutant_of_the_check_that_a_file_is_the_script_in_a_condition
    assert_empty(edits("if __FILE__ == $0\n  run\nend\n"))
  end

  def test_makes_no_mutant_of_the_check_that_a_file_is_the_script_wherever_it_stands
    sources = ["ok = __FILE__ == $0\n", "run(__FILE__ == $0)\n", "[$0 == __FILE__]\n", "x = (__FILE__ == $0) && y\n"]

    assert_empty(sources.flat_map { |source| edits(source) })
  end

  def test_makes_a_mutant_of_a_comparison_of_the_file_with_something_else
    assert_equal(["__FILE__ != name", "$0 != name"], replacements("__FILE__ == name") + replacements("$0 == name"))
  end

  def test_makes_a_mutant_of_a_comparison_of_the_script_name_with_itself_or_the_file_with_itself
    mutants = replacements("$0 == $PROGRAM_NAME") + replacements("__FILE__ == __FILE__")

    assert_equal(["$0 != $PROGRAM_NAME", "__FILE__ != __FILE__"], mutants)
  end

  def test_makes_a_mutant_of_a_not_equal_check_of_the_file_and_the_script
    assert_equal(["__FILE__ == $0"], replacements("__FILE__ != $0"))
  end
end
