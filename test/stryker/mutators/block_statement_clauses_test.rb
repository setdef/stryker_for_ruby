# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/block_statement"
require_relative("../../support/mutator_case")

# Checks the pairs of BlockStatement for the clauses of a case, loops, and
# begin, from its section of docs/contributors/design/mutators.md.
class BlockStatementClausesTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::BlockStatement
  end

  def test_each_clause_of_a_case_becomes_nil_with_its_else
    assert_equal(
      [
        "case x when 1 then nil when 2 then b else c end",
        "case x when 1 then a when 2 then nil else c end",
        "case x when 1 then a when 2 then b else nil end",
],
      mutated("case x when 1 then a when 2 then b else c end")
    )
  end

  def test_each_clause_of_a_case_in_becomes_nil_with_its_else
    assert_equal(
      ["case x; in 1 then nil else b end", "case x; in 1 then a else nil end"],
      mutated("case x; in 1 then a else b end")
    )
  end

  def test_the_body_of_a_while_loop_becomes_nil
    assert_equal(["while a do nil end"], mutated("while a do b end"))
  end

  def test_the_statement_of_a_modifier_loop_becomes_nil
    assert_equal(["nil while a"], mutated("b while a"))
  end

  def test_the_body_of_a_for_loop_becomes_nil
    assert_equal(["for i in 1..2 do nil end"], mutated("for i in 1..2 do b end"))
  end

  def test_the_body_of_a_begin_becomes_nil
    assert_equal(["begin; nil; end"], mutated("begin; a; end"))
  end

  def test_the_body_of_a_begin_end_while_becomes_nil_and_so_does_the_whole_begin
    assert_equal(["nil while a", "begin; nil; end while a"], mutated("begin; b; end while a"))
  end

  def test_the_bodies_of_a_begin_with_rescue_else_and_ensure_become_nil_one_at_a_time
    assert_equal(
      [
        "begin; nil; rescue X; b; else; c; ensure; d; end",
        "begin; a; rescue X; nil; else; c; ensure; d; end",
        "begin; a; rescue X; b; else; nil; ensure; d; end",
        "begin; a; rescue X; b; else; c; ensure; nil; end",
      ],
      mutated("begin; a; rescue X; b; else; c; ensure; d; end")
    )
  end

  def test_the_bodies_of_a_method_with_rescue_and_ensure_become_nil_one_at_a_time
    assert_equal(
      [
        "def f; nil; rescue; b; ensure; d; end",
        "def f; a; rescue; nil; ensure; d; end",
        "def f; a; rescue; b; ensure; nil; end",
],
      mutated("def f; a; rescue; b; ensure; d; end")
    )
  end

  def test_the_bodies_of_a_block_with_rescue_become_nil
    assert_equal(
      ["x.each do |i| nil; rescue; b; end", "x.each do |i| a; rescue; nil; end"],
      mutated("x.each do |i| a; rescue; b; end")
    )
  end
end
