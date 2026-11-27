# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/optional_chaining"
require_relative("../../support/mutator_case")

# Checks the calls that OptionalChaining makes no mutant of, from its section
# of docs/contributors/design/mutators.md.
class OptionalChainingSkipsTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::OptionalChaining
  end

  def test_makes_no_mutant_of_a_call_with_a_dot
    assert_empty(edits("order.total\norder.total = 0\norder.total += 1\norder.total ||= 0\n"))
  end

  def test_makes_no_mutant_of_a_call_with_a_scope_operator_or_no_operator
    assert_empty(edits("Order::total\ntotal\nf(1)\na + b\na[0]\n"))
  end

  def test_makes_no_mutant_when_the_receiver_is_self
    assert_empty(edits("self&.total\nself&.total = 1\nself&.total += 1\n"))
  end

  def test_makes_no_mutant_when_the_receiver_is_a_number
    assert_empty(edits("1&.succ\n1.5&.floor\n2r&.numerator\n3i&.imaginary\n"))
  end

  def test_makes_no_mutant_when_the_receiver_is_a_string
    assert_empty(edits("'a'&.size\n\"a\#{b}\"&.size\n?a&.size\n`ls`&.size\n"))
  end

  def test_makes_no_mutant_when_the_receiver_is_a_symbol_or_a_regexp
    assert_empty(edits(":a&.size\n:\"a\#{b}\"&.size\n/a/&.source\n/a\#{b}/&.source\n"))
  end

  def test_makes_no_mutant_when_the_receiver_is_an_array_or_a_hash
    assert_empty(edits("[1]&.size\n%w[a]&.size\n{ a: 1 }&.size\n"))
  end

  def test_makes_no_mutant_when_the_receiver_is_true_or_false
    assert_empty(edits("true&.to_s\nfalse&.to_s\n"))
  end

  def test_makes_no_mutant_when_the_receiver_is_a_lambda
    assert_empty(edits("->(x) { x }&.call(1)\n"))
  end

  def test_makes_no_mutant_when_the_receiver_is_a_source_constant
    assert_empty(edits("__FILE__&.size\n__LINE__&.succ\n__ENCODING__&.name\n"))
  end

  def test_makes_a_mutant_of_a_chain_after_a_literal_receiver
    assert_equal(["1&.succ.succ"], mutated("1&.succ&.succ"))
  end

  def test_makes_a_mutant_of_the_safe_navigation_inside_a_literal_array
    assert_equal(["[a.b]"], mutated("[a&.b]"))
  end
end
