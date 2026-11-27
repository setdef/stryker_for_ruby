# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/object_literal"
require_relative("../../support/mutator_case")

# Checks the pairs of ObjectLiteral and the nodes it makes no mutant of, from
# its section of docs/contributors/design/mutators.md.
class ObjectLiteralTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::ObjectLiteral
  end

  def test_is_named_for_the_report
    assert_equal("ObjectLiteral", mutator.name)
  end

  def test_a_hash_becomes_an_empty_one
    assert_equal(["{}"], replacements("{ rate: 0.1, cap: 50 }"))
  end

  def test_a_hash_with_rockets_becomes_an_empty_one
    assert_equal(["{}"], replacements("{ 'rate' => 0.1 }"))
  end

  def test_a_hash_with_a_double_splat_becomes_an_empty_one
    assert_equal(["{}"], replacements("{ **defaults }"))
  end

  def test_a_hash_with_a_shorthand_value_becomes_an_empty_one
    assert_equal(["{}"], replacements("{ rate: }"))
  end

  def test_the_edit_covers_the_whole_hash
    edit = edits("ok = { a: 1 }\n").first

    assert_equal([5, 13, "{}"], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_the_mutant_is_the_whole_file_with_the_hash_emptied
    assert_equal(["ok = {}\n"], mutated("ok = { a: 1 }\n"))
  end

  def test_a_hash_across_lines_becomes_an_empty_one
    assert_equal(["ok = {}\n"], mutated("ok = {\n  a: 1,\n  b: 2,\n}\n"))
  end

  def test_makes_a_mutant_for_each_hash_in_the_order_of_the_tree
    assert_equal(["{}", "{}"], replacements("{ a: { b: 1 } }"))
  end

  def test_makes_a_mutant_of_a_hash_that_is_a_keyword_arguments_value
    assert_equal(["f(a: {})"], mutated("f(a: { b: 1 })"))
  end

  def test_makes_a_mutant_of_a_hash_that_is_an_argument
    assert_equal(["f({})"], mutated("f({ a: 1 })"))
  end

  def test_makes_no_mutant_of_an_empty_hash
    assert_empty(edits("{}\n{ }\n"))
  end

  def test_makes_no_mutant_of_keyword_arguments
    assert_empty(edits("Discount.new(rate: 0.1)\nf('a' => 1)\nf(**opts)\n"))
  end

  def test_makes_no_mutant_of_keyword_arguments_written_without_parentheses
    assert_empty(edits("puts a: 1\n"))
  end

  def test_makes_no_mutant_of_the_keyword_arguments_of_an_index
    assert_empty(edits("h[a: 1]\nsuper(a: 1)\nyield a: 1\n"))
  end

  def test_makes_no_mutant_of_the_hash_without_braces_in_an_array
    assert_empty(edits("[1, a: 2]"))
  end

  def test_makes_no_mutant_of_a_hash_pattern
    assert_empty(edits("case x\nin { a: 1 } then 1\nend"))
  end
end
