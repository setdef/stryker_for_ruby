# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/array_declaration"
require_relative("../../support/mutator_case")

# Checks the pairs of ArrayDeclaration and the nodes it makes no mutant of, from
# its section of docs/contributors/design/mutators.md.
class ArrayDeclarationTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::ArrayDeclaration
  end

  def test_is_named_for_the_report
    assert_equal("ArrayDeclaration", mutator.name)
  end

  def test_an_array_becomes_an_empty_one
    assert_equal(["[]"], replacements("[a, b]"))
  end

  def test_a_word_array_becomes_an_empty_one
    assert_equal(["[]"], replacements("%w[a b]"))
  end

  def test_a_symbol_array_becomes_an_empty_one
    assert_equal(["[]"], replacements("%i[a b]"))
  end

  def test_an_array_with_a_splat_becomes_an_empty_one
    assert_equal(["[]"], replacements("[*items]"))
  end

  def test_an_array_with_one_element_becomes_an_empty_one
    assert_equal(["[]"], replacements("[1]"))
  end

  def test_the_edit_covers_the_whole_array
    edit = edits("ok = [1, 2]\n").first

    assert_equal([5, 11, "[]"], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_the_mutant_is_the_whole_file_with_the_array_emptied
    assert_equal(["ok = []\n"], mutated("ok = [1, 2]\n"))
  end

  def test_an_empty_array_becomes_one_with_text
    assert_equal(['["Stryker was here"]'], replacements("[]"))
  end

  def test_an_empty_array_with_a_space_becomes_one_with_text
    assert_equal(['["Stryker was here"]'], replacements("[ ]"))
  end

  def test_an_empty_word_array_becomes_one_with_text
    assert_equal(['["Stryker was here"]', '["Stryker was here"]'], replacements("%w[]\n%i[]\n"))
  end

  def test_an_array_that_holds_an_empty_array_makes_two_mutants_in_the_order_of_the_tree
    assert_equal(["[]", '["Stryker was here"]'], replacements("[[]]"))
  end

  def test_a_constructor_with_arguments_becomes_one_with_none
    assert_equal(["Array.new"], replacements("Array.new(3, 0)"))
  end

  def test_a_constructor_with_one_argument_becomes_one_with_none
    assert_equal(["Array.new"], replacements("Array.new(3)"))
  end

  def test_a_constructor_with_a_block_and_an_argument_becomes_one_with_none
    assert_equal(["Array.new"], replacements("Array.new(3) { |i| i * 2 }"))
  end

  def test_a_constructor_with_no_parentheses_becomes_one_with_none
    assert_equal(["Array.new"], replacements("Array.new 3, 0"))
  end

  def test_a_constructor_with_a_leading_scope_operator_keeps_it
    assert_equal(["::Array.new"], replacements("::Array.new(3)"))
  end

  def test_the_edit_of_a_constructor_covers_the_whole_call
    edit = edits("ok = Array.new(3, 0)\n").first

    assert_equal([5, 20, "Array.new"], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_a_constructor_inside_an_expression_becomes_one_with_none
    assert_equal(["Array.new.size"], mutated("Array.new(3).size"))
  end

  def test_makes_a_mutant_for_each_array_in_the_order_of_the_tree
    assert_equal(["[]", "[]", "[]", '["Stryker was here"]'], replacements("[[1], [2], []]"))
  end
end
