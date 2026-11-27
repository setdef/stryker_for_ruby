# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/method_expression"
require_relative("../../support/mutator_case")

# Checks the calls that MethodExpression makes no mutant of, from its section of
# docs/contributors/design/mutators.md.
class MethodExpressionSkipsTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::MethodExpression
  end

  def test_makes_no_mutant_of_a_call_with_no_receiver
    assert_empty(edits("first\nsort\nstrip\nfirst(2)\nupcase!\n"))
  end

  def test_makes_no_mutant_of_a_method_that_is_not_listed
    assert_empty(edits("items.each\nitems.map { |i| i }\nitems.size\nname.length\nitems.prepend(1)\nitems.append(1)\n"))
  end

  def test_makes_no_mutant_of_freeze
    assert_empty(edits("NAMES.freeze\n'a'.freeze\nitems.dup.freeze\n"))
  end

  def test_makes_no_mutant_of_an_attribute_write_or_a_name_with_other_characters
    assert_empty(edits("items.first = 1\nitems.sort = 1\nitems.first2\nitems.firstx\nitems.rfirst\n"))
  end

  def test_makes_no_mutant_of_a_listed_name_used_as_a_variable_or_a_symbol
    assert_empty(edits("first = 1\nitems.map(&:first)\nitems.send(:sort)\n"))
  end

  def test_makes_no_mutant_of_filter_with_a_bang
    assert_empty(edits("items.filter!(&:ok?)\nitems.collect\n"))
  end

  def test_makes_a_mutant_of_a_call_in_the_receiver_of_a_call_that_is_not_listed
    assert_equal(["items.last.size"], mutated("items.first.size"))
  end

  def test_makes_a_mutant_of_a_listed_call_that_is_an_argument
    assert_equal(["f(items.last)"], mutated("f(items.first)"))
  end
end
