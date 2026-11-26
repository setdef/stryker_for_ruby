# frozen_string_literal: true

require_relative("../../test_helper")
require "prism"
require "stryker/mutators/comparison"

# Checks what a comparison adds to an operation: the swap of its operands, and
# the check that a file is the script that runs.
class ComparisonTest < Minitest::Test
  def comparison(source, names)
    Stryker::Mutators::Comparison.of(Prism.parse(source).value.statements.body.first, names)
  end

  def test_is_an_operation_made_by_of
    assert_instance_of(Stryker::Mutators::Comparison, comparison("a <=> b", %i[<=>]))
  end

  def test_swaps_its_operands_in_an_edit_that_covers_the_whole_call
    call = Prism.parse("total = a  <=>\n  b").value.statements.body.first.value
    edit = Stryker::Mutators::Comparison.of(call, %i[<=>]).swapped

    assert_equal([8, 18, "b  <=>\n  a"], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_swaps_nothing_when_the_operands_have_the_same_text
    assert_nil(comparison("a.b <=> a.b", %i[<=>]).swapped)
  end

  def test_swaps_nothing_when_an_operand_holds_a_heredoc_opener
    sources = ["a <=> <<~TEXT\n  b\nTEXT\n", "<<~TEXT <=> a\n  b\nTEXT\n", "f(<<~TEXT) <=> a\n  b\nTEXT\n"]

    assert_equal([nil] * 3, sources.map { |source| comparison(source, %i[<=>]).swapped })
  end

  # Ruby parses no bare and, or, or not as an operand, so these comparisons are
  # built by hand, with the operand taken out of its parentheses.
  def test_puts_a_swapped_operand_that_is_a_bare_and_or_or_or_not_in_parentheses
    swapped = ["a <=> (b and c)", "a <=> (b or c)", "a <=> (not b)"].map { |source| bare_operand_swap(source) }

    assert_equal(["(b and c) <=> (a)", "(b or c) <=> (a)", "(not b) <=> (a)"], swapped)
  end

  def bare_operand_swap(source)
    call = Prism.parse(source).value.statements.body.first
    arguments = call.arguments.copy(arguments: [bare_argument(call)])
    Stryker::Mutators::Comparison.of(call.copy(arguments:), %i[<=>]).swapped.replacement
  end

  def bare_argument(call)
    call.arguments.arguments.first.body.body.first
  end

  def test_a_comparison_of_the_file_with_the_script_name_says_so
    checks = ["__FILE__ == $0", "$0 == __FILE__", "__FILE__ == $PROGRAM_NAME", "$PROGRAM_NAME == __FILE__"]

    assert_equal([true] * 4, checks.map { |source| comparison(source, %i[==]).script_check? })
  end

  def test_a_comparison_of_something_else_is_no_script_check
    others = ["__FILE__ == name", "name == $0", "$0 == $PROGRAM_NAME", "__FILE__ == __FILE__", "__FILE__ != $0"]

    assert_equal([false] * 5, others.map { |source| comparison(source, %i[== !=]).script_check? })
  end
end
