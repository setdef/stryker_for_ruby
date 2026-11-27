# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/logical_operator"
require_relative("../../support/mutator_case")

# Checks the pairs of LogicalOperator and the nodes it makes no mutant of, from
# its section of docs/contributors/design/mutators.md.
class LogicalOperatorTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::LogicalOperator
  end

  def test_is_named_for_the_report
    assert_equal("LogicalOperator", mutator.name)
  end

  def test_and_becomes_or
    assert_equal(["a || b"], replacements("a && b"))
  end

  def test_or_becomes_and
    assert_equal(["a && b"], replacements("a || b"))
  end

  def test_the_keyword_and_becomes_the_keyword_or
    assert_equal(["a or b"], replacements("a and b"))
  end

  def test_the_keyword_or_becomes_the_keyword_and
    assert_equal(["a and b"], replacements("a or b"))
  end

  def test_the_edit_covers_the_whole_node
    edit = edits("ok = a && b\n").first

    assert_equal([5, 11, "a || b"], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_the_mutant_is_the_whole_file_with_the_operator_changed
    assert_equal(["ok = a || b\n"], mutated("ok = a && b\n"))
  end

  def test_keeps_the_text_between_the_operands
    spaced = ["a&&b", "a  &&  b", "a &&\n  b", "a and\n  b"].map { |source| replacements(source).first }

    assert_equal(["a||b", "a  ||  b", "a ||\n  b", "a or\n  b"], spaced)
  end

  def test_keeps_multibyte_operands_whole
    assert_equal(["réponse || prix"], replacements("réponse && prix"))
  end

  def test_makes_a_mutant_for_each_operator_in_an_expression_in_the_order_of_the_tree
    assert_equal(["a && b && c", "b || c"], replacements("a || b && c"))
  end

  def test_a_chain_of_ors_groups_its_first_operands_when_the_last_or_becomes_an_and
    # Written as a || b && c, the mutant would mean a || (b && c).
    assert_equal(["(a || b) && c", "a && b"], replacements("a || b || c"))
  end

  def test_a_longer_chain_of_ors_groups_all_its_first_operands
    assert_equal(["(a || b || c) && d", "(a || b) && c", "a && b"], replacements("a || b || c || d"))
  end

  def test_the_grouping_keeps_the_text_around_the_operands
    assert_equal(["(a  ||  b)  &&\n  c", "a  &&  b"], replacements("a  ||  b  ||\n  c"))
  end

  def test_a_chain_of_ands_needs_no_grouping_when_the_last_and_becomes_an_or
    assert_equal(["a && b || c", "a || b"], replacements("a && b && c"))
  end

  def test_an_and_inside_an_or_needs_no_grouping_when_the_or_becomes_an_and
    assert_equal(["a && b && c", "a || b"], replacements("a && b || c"))
  end

  def test_a_chain_of_keyword_ors_needs_no_grouping
    assert_equal(["a or b and c", "a and b"], replacements("a or b or c"))
  end

  def test_a_keyword_or_after_a_symbol_or_needs_no_grouping
    assert_equal(["a || b and c", "a && b"], replacements("a || b or c"))
  end

  def test_an_or_after_a_parenthesized_or_needs_no_grouping
    assert_equal(["(a || b) && c", "a && b"], replacements("(a || b) || c"))
  end

  def test_makes_no_mutant_of_a_node_that_is_not_a_logical_operator
    assert_empty(edits("a = 1\n[1, 2]\nx if y\na + b\n!a\nnot a\na == b\n"))
  end
end
