# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/range_operator"
require_relative("../../support/mutator_case")

# Checks the pairs of RangeOperator and the nodes it makes no mutant of, from
# its section of docs/contributors/design/mutators.md.
class RangeOperatorTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::RangeOperator
  end

  def test_is_named_for_the_report
    assert_equal("RangeOperator", mutator.name)
  end

  def test_an_inclusive_range_becomes_an_exclusive_one
    assert_equal(["a...b"], replacements("a..b"))
  end

  def test_an_exclusive_range_becomes_an_inclusive_one
    assert_equal(["a..b"], replacements("a...b"))
  end

  def test_a_beginless_inclusive_range_becomes_an_exclusive_one
    assert_equal(["...b"], replacements("..b"))
  end

  def test_a_beginless_exclusive_range_becomes_an_inclusive_one
    assert_equal(["..b"], replacements("...b"))
  end

  def test_the_edit_covers_the_whole_range
    edit = edits("ok = (0..items.size)\n").first

    assert_equal([6, 19, "0...items.size"], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_the_mutant_is_the_whole_file_with_the_operator_changed
    assert_equal(["ok = (0...items.size)\n"], mutated("ok = (0..items.size)\n"))
  end

  def test_a_range_with_spaces_keeps_them
    assert_equal(["a ... b"], replacements("a .. b"))
  end

  def test_a_range_of_numbers_and_floats
    assert_equal(["1.5...2", "-1...1"], replacements("1.5..2") + replacements("-1..1"))
  end

  def test_a_range_of_strings
    assert_equal(["'a'...'z'"], replacements("'a'..'z'"))
  end

  def test_a_range_in_a_when_clause
    assert_equal(["case x when 1...10 then 1 end"], mutated("case x when 1..10 then 1 end"))
  end

  def test_a_range_in_a_pattern
    assert_equal(["case x; in 1...3 then 1; end"], mutated("case x; in 1..3 then 1; end"))
  end

  def test_a_range_in_a_for_loop
    assert_equal(["for i in 1...3 do x end"], mutated("for i in 1..3 do x end"))
  end

  def test_a_range_as_an_argument_and_an_index
    assert_equal(["f(a...b)", "s[1...2]"], mutated("f(a..b)") + mutated("s[1..2]"))
  end

  def test_makes_a_mutant_for_each_range_in_the_order_of_the_tree
    assert_equal(["(a..b)...c", "(a...b)..c"], mutated("(a..b)..c"))
  end
end
