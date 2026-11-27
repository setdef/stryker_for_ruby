# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/string_literal"
require_relative("../../support/mutator_case")

# Checks the strings that StringLiteral makes no mutant of, from its section of
# docs/contributors/design/mutators.md.
class StringLiteralSkipsTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::StringLiteral
  end

  def test_makes_no_mutant_of_the_key_of_a_hash_pair
    assert_empty(edits(%({ "rate" => 0.1, 'cap' => 50 })))
  end

  def test_makes_no_mutant_of_an_interpolated_key_of_a_hash_pair
    assert_empty(edits("{ \"rate\#{n}\" => 0.1 }"))
  end

  def test_makes_no_mutant_of_the_key_of_a_keyword_argument_written_with_a_rocket
    assert_empty(edits(%(f("rate" => 0.1))))
  end

  def test_makes_no_mutant_of_an_element_of_a_percent_w_array
    assert_empty(edits("%w[a b]"))
  end

  def test_makes_no_mutant_of_an_element_of_a_percent_capital_w_array
    assert_empty(edits("%W[a b\#{c}]"))
  end

  def test_makes_no_mutant_of_the_pattern_given_to_regexp_new
    assert_empty(edits('Regexp.new("a+")'))
  end

  def test_makes_no_mutant_of_the_pattern_given_to_a_regexp_with_a_leading_scope_operator
    assert_empty(edits('::Regexp.new("a+")'))
  end

  def test_makes_no_mutant_of_a_command
    assert_empty(edits("`ls`\n%x(ls)\n`ls \#{dir}`\n"))
  end

  def test_makes_no_mutant_of_a_string_in_a_block_inside_an_interpolation
    assert_equal(['""'], replacements("\"a \#{items.map { |item| \"b\" }} c\""))
  end

  def test_makes_no_mutant_of_a_string_inside_an_interpolated_symbol_or_regexp
    assert_empty(edits(%(:"a\#{"b"}"\n/a\#{"b"}/\n)))
  end

  def test_makes_one_mutant_of_a_string_made_of_adjacent_literals
    assert_equal(1, edits(%("a" 'b')).size)
  end

  def test_makes_no_mutant_of_a_symbol_or_a_number
    assert_empty(edits(":a\n:\"a b\"\n1\n"))
  end

  def test_makes_a_mutant_of_the_options_given_to_regexp_new
    assert_equal(['""'], replacements('Regexp.new("a+", "b")').last(1))
  end

  def test_makes_a_mutant_of_the_strings_of_an_array_with_no_brackets
    assert_equal(['""', '""'], replacements("a, b = 'x', 'y'"))
  end

  def test_makes_a_mutant_of_a_string_given_to_new_with_no_class_in_front
    assert_equal(['""', '""'], replacements("new('a+')\nitem.new('b')\n"))
  end

  def test_makes_a_mutant_of_a_string_given_to_the_new_of_a_class_in_a_module
    assert_equal(['""'], replacements("Tools::Regexp.new('a+')"))
  end

  def test_makes_a_mutant_of_a_string_given_to_another_new
    assert_equal(['""'], replacements('Pattern.new("a+")'))
  end

  def test_makes_a_mutant_of_the_pattern_given_to_regexp_new_through_a_variable
    assert_equal(['""'], replacements('source = "a+"; Regexp.new(source)'))
  end

  def test_makes_a_mutant_of_a_pattern_in_a_case_in
    assert_equal(['""'], replacements(%(case x\nin "a" then 1\nend)))
  end

  def test_makes_a_mutant_of_a_string_in_a_when_clause
    assert_equal(['""'], replacements(%(case x\nwhen "a" then 1\nend)))
  end
end
