# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/array_declaration"
require_relative("../../support/mutator_case")

# Checks the arrays that ArrayDeclaration makes no mutant of, from its section
# of docs/contributors/design/mutators.md.
class ArrayDeclarationSkipsTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::ArrayDeclaration
  end

  def test_makes_no_mutant_of_the_array_with_no_brackets_on_the_right_of_a_multiple_assignment
    assert_empty(edits("a, b = 1, 2"))
  end

  def test_makes_no_mutant_of_an_array_with_no_brackets_on_the_right_of_an_assignment
    assert_empty(edits("a = 1, 2"))
  end

  def test_makes_a_mutant_of_a_bracketed_array_on_the_right_of_a_multiple_assignment
    assert_equal(["[]"], replacements("a, b = [1, 2]"))
  end

  def test_makes_a_mutant_of_an_array_inside_the_array_with_no_brackets
    assert_equal(["[]"], replacements("a, b = [1], 2"))
  end

  def test_makes_no_mutant_of_a_constructor_with_no_arguments
    assert_empty(edits("Array.new"))
  end

  def test_makes_no_mutant_of_a_constructor_with_empty_parentheses
    assert_empty(edits("Array.new()"))
  end

  def test_makes_no_mutant_of_a_constructor_with_a_block_and_no_arguments
    assert_empty(edits("Array.new { 1 }"))
  end

  def test_makes_no_mutant_of_a_constructor_given_an_empty_array_but_one_of_the_array
    assert_equal(['["Stryker was here"]'], replacements("Array.new([])"))
  end

  def test_makes_no_mutant_of_a_constructor_of_another_class
    assert_empty(edits("Set.new(3)\nHash.new(3)\nArray.build(3)\nArray(3)\nArray[3]\n"))
  end

  def test_makes_no_mutant_of_a_constructor_called_on_a_variable_named_array
    assert_empty(edits("array.new(3)\nself.Array.new(3)\nx::Array.new(3)\n"))
  end

  def test_makes_no_mutant_of_an_array_pattern
    assert_empty(edits("case x\nin [a, b] then 1\nend"))
  end

  def test_makes_no_mutant_of_the_arguments_of_a_call_or_the_targets_of_an_assignment
    assert_empty(edits("f(1, 2)\na, b = x\nreturn 1, 2\n"))
  end
end
