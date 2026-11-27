# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/conditional_expression"
require_relative("../../support/mutator_case")

# Checks the pairs of ConditionalExpression for the conditions of branches and
# loops, from its section of docs/contributors/design/mutators.md.
class ConditionalExpressionTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::ConditionalExpression
  end

  def test_is_named_for_the_report
    assert_equal("ConditionalExpression", mutator.name)
  end

  def test_the_condition_of_an_if_becomes_true_and_false
    assert_equal(["if true then x end", "if false then x end"], mutated("if c then x end"))
  end

  def test_the_edit_covers_the_whole_condition
    edit = edits("if a.ready? then x end").first

    assert_equal([3, 11, "true"], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_any_expression_is_a_condition_of_an_if
    assert_equal(%w[true false], replacements("if order then x end"))
  end

  def test_the_condition_of_an_elsif_becomes_true_and_false
    assert_equal(
      [
        "if a then x elsif true then y end",
        "if a then x elsif false then y end",
        "if true then x elsif c then y end",
        "if false then x elsif c then y end",
      ].sort,
      mutated("if a then x elsif c then y end").sort
    )
  end

  def test_the_condition_of_an_unless_becomes_true_and_false
    assert_equal(["unless true then x end", "unless false then x end"], mutated("unless c then x end"))
  end

  def test_the_condition_of_a_ternary_becomes_true_and_false
    assert_equal(["true ? a : b", "false ? a : b"], mutated("c ? a : b"))
  end

  def test_the_condition_of_a_modifier_if_becomes_true_and_false
    assert_equal(["x if true", "x if false"], mutated("x if c"))
  end

  def test_the_condition_of_a_modifier_unless_becomes_true_and_false
    assert_equal(["x unless true", "x unless false"], mutated("x unless c"))
  end

  def test_the_guard_of_a_case_in_becomes_true_and_false
    assert_equal(
      ["case x; in Integer => n if true then 1; end", "case x; in Integer => n if false then 1; end"],
      mutated("case x; in Integer => n if c then 1; end")
    )
  end

  def test_the_guard_of_a_case_in_with_unless_becomes_true_and_false
    assert_equal(
      ["case x; in Integer unless true then 1; end", "case x; in Integer unless false then 1; end"],
      mutated("case x; in Integer unless c then 1; end")
    )
  end

  def test_the_condition_of_a_while_loop_becomes_only_false
    assert_equal(["while false do x end"], mutated("while c do x end"))
  end

  def test_the_condition_of_a_modifier_while_becomes_only_false
    assert_equal(["x while false"], mutated("x while c"))
  end

  def test_the_condition_of_a_begin_end_while_becomes_only_false
    assert_equal(["begin; x; end while false"], mutated("begin; x; end while c"))
  end

  def test_the_condition_of_an_until_loop_becomes_only_true
    assert_equal(["until true do x end"], mutated("until c do x end"))
  end

  def test_the_condition_of_a_modifier_until_becomes_only_true
    assert_equal(["x until true"], mutated("x until c"))
  end

  def test_the_condition_of_a_begin_end_until_becomes_only_true
    assert_equal(["begin; x; end until true"], mutated("begin; x; end until c"))
  end

  def test_a_condition_with_multibyte_characters_becomes_true_and_false
    assert_equal(["if true then x end", "if false then x end"], mutated("if réponse then x end"))
  end
end
