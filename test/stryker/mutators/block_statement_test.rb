# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/block_statement"
require_relative("../../support/mutator_case")

# Checks the pairs of BlockStatement from its section of
# docs/contributors/design/mutators.md.
class BlockStatementTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::BlockStatement
  end

  def test_is_named_for_the_report
    assert_equal("BlockStatement", mutator.name)
  end

  def test_the_body_of_a_method_becomes_nil
    source = "def apply(order)\n  total = order.total\n  total.round(2)\nend\n"

    assert_equal(["def apply(order)\n  nil\nend\n"], mutated(source))
  end

  def test_the_edit_covers_the_statements_of_the_body
    edit = edits("def f\n  a\n  b\nend\n").first

    assert_equal([8, 13, "nil"], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_the_body_of_an_endless_method_becomes_nil
    assert_equal(["def f(x) = nil"], mutated("def f(x) = x + 1"))
  end

  def test_the_body_of_a_block_with_braces_becomes_nil
    assert_equal(["items.map { |item| nil }"], mutated("items.map { |item| item.price }"))
  end

  def test_the_body_of_a_block_with_do_becomes_nil
    assert_equal(["items.each do |item| nil end"], mutated("items.each do |item| item.save end"))
  end

  def test_the_body_of_a_lambda_becomes_nil
    assert_equal(["-> { nil }"], mutated("-> { x }"))
  end

  def test_the_body_of_a_lambda_with_parameters_becomes_nil
    assert_equal(["->(x) { nil }"], mutated("->(x) { x * 2 }"))
  end

  def test_each_branch_of_an_if_becomes_nil_in_the_order_of_the_tree
    assert_equal(
      [
        "if a then nil elsif c then d else e end",
        "if a then b elsif c then nil else e end",
        "if a then b elsif c then d else nil end",
      ],
      mutated("if a then b elsif c then d else e end")
    )
  end

  def test_the_body_of_an_unless_and_its_else_become_nil
    assert_equal(
      ["unless a then nil else c end", "unless a then b else nil end"],
      mutated("unless a then b else c end")
    )
  end

  def test_the_statement_of_a_modifier_if_becomes_nil
    assert_equal(["nil if ready"], mutated("save if ready"))
  end

  def test_the_statement_of_a_modifier_unless_becomes_nil
    assert_equal(["nil unless ready"], mutated("save unless ready"))
  end

  def test_each_branch_of_a_ternary_becomes_nil
    assert_equal(["ready ? nil : b", "ready ? a : nil"], mutated("ready ? a : b"))
  end

  def test_the_body_of_an_until_loop_becomes_nil
    assert_equal(["until a do nil end"], mutated("until a do b end"))
  end

  def test_a_body_inside_a_body_makes_a_mutant_for_each_in_the_order_of_the_tree
    assert_equal(2, edits("def f\n  items.map { |item| item.price }\nend\n").size)
  end

  def test_the_statements_of_a_multibyte_body_become_nil
    assert_equal(["def f = nil"], mutated("def f = 'réponse'"))
  end
end
