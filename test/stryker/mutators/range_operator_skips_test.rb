# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/range_operator"
require_relative("../../support/mutator_case")

# Checks the ranges that RangeOperator makes no mutant of, from its section of
# docs/contributors/design/mutators.md.
class RangeOperatorSkipsTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::RangeOperator
  end

  def test_makes_no_mutant_of_an_endless_inclusive_range
    assert_empty(edits("items[1..]\n(1..)\n"))
  end

  def test_makes_no_mutant_of_an_endless_exclusive_range
    assert_empty(edits("items[1...]\n(1...)\n"))
  end

  def test_makes_no_mutant_of_a_flip_flop
    assert_empty(edits("r << i if (i == 2)..(i == 4)\n"))
  end

  def test_makes_no_mutant_of_a_flip_flop_with_three_dots
    assert_empty(edits("r << i if (i == 2)...(i == 4)\n"))
  end

  def test_makes_no_mutant_of_a_flip_flop_in_a_while_or_a_ternary
    assert_empty(edits("work while (i == 2)..(i == 4)\n((a)..(b)) ? x : y\n"))
  end

  def test_makes_a_mutant_of_a_range_that_is_not_in_a_condition_of_a_flip_flop
    assert_equal(["r << i if (1...3).include?(i)"], mutated("r << i if (1..3).include?(i)"))
  end

  def test_makes_a_mutant_of_a_range_inside_the_endpoint_of_a_flip_flop
    assert_equal(["r << i if (i == (1...2))..(i == 4)"], mutated("r << i if (i == (1..2))..(i == 4)"))
  end

  def test_makes_no_mutant_of_a_symbol_or_a_method_with_dots
    assert_empty(edits("a.b\na&.b\ndef g(...) = f(...)\n:\"a..b\"\n"))
  end
end
