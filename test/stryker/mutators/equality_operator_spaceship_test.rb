# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/equality_operator"
require_relative("../../support/mutator_case")

# Checks the swap that EqualityOperator makes of <=>, and the calls it makes no
# swap of, from its section of docs/design/mutators.md.
class EqualityOperatorSpaceshipTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::EqualityOperator
  end

  def test_swaps_its_operands
    assert_equal(["b <=> a"], replacements("a <=> b"))
  end

  def test_keeps_the_text_between_the_operands
    spaced = ["a<=>b", "a  <=>  b", "a <=>\n  b"].map { |source| replacements(source).first }

    assert_equal(["b<=>a", "b  <=>  a", "b <=>\n  a"], spaced)
  end

  def test_swaps_operands_that_are_calls_and_multibyte
    assert_equal(["items[2].size <=> réponse"], replacements("réponse <=> items[2].size"))
  end

  def test_swaps_each_spaceship_in_an_expression_in_the_order_of_the_tree
    assert_equal(["(b <=> c) <=> a", "a <=> (c <=> b)"], mutated("a <=> (b <=> c)"))
  end

  def test_makes_no_mutant_when_the_operands_have_the_same_text
    assert_empty(edits("x <=> x\nf(1, 2) <=> f(1, 2)\n@a <=> @a"))
  end

  def test_makes_a_mutant_when_the_operands_differ_in_any_character
    assert_equal(["x1 <=> x", "x <=> x.y"], replacements("x <=> x1") + replacements("x.y <=> x"))
  end

  def test_makes_no_mutant_when_both_operands_hold_a_heredoc_opener
    # Swapping the openers would give each the other's body.
    assert_empty(edits("foo(<<~A) <=> bar(<<~B)\n  a\nA\n  b\nB\n"))
  end

  def test_makes_no_mutant_when_the_right_operand_is_a_heredoc_opener
    assert_empty(edits("x <=> <<~A\n  a\nA\n"))
  end

  def test_makes_no_mutant_when_the_left_operand_is_a_heredoc_opener
    assert_empty(edits("<<~A <=> x\n  a\nA\n"))
  end

  def test_makes_no_mutant_when_an_opener_is_deep_inside_an_operand
    assert_empty(edits("x <=> f(g(<<~A.strip))\n  a\nA\n"))
  end

  def test_makes_a_mutant_when_an_operand_holds_a_string_but_no_opener
    assert_equal(["f('b') <=> 'a'"], replacements("'a' <=> f('b')"))
  end

  def test_swaps_a_spaceship_inside_a_heredoc_body
    assert_equal(["b <=> a"], replacements("<<~A\n  \#{a <=> b}\nA\n"))
  end
end
