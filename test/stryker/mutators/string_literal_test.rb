# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/string_literal"
require_relative("../../support/mutator_case")

# Checks the pairs of StringLiteral and the nodes it makes no mutant of, from
# its section of docs/contributors/design/mutators.md.
class StringLiteralTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::StringLiteral
  end

  def test_is_named_for_the_report
    assert_equal("StringLiteral", mutator.name)
  end

  def test_a_double_quoted_string_becomes_an_empty_one
    assert_equal(['""'], replacements('"Free shipping"'))
  end

  def test_a_single_quoted_string_becomes_an_empty_one
    assert_equal(['""'], replacements("'Free shipping'"))
  end

  def test_a_character_literal_becomes_an_empty_string
    assert_equal(['""'], replacements("?a"))
  end

  def test_a_percent_literal_becomes_an_empty_string
    assert_equal(['""', '""'], replacements("%q(a)\n%Q(b)\n"))
  end

  def test_an_empty_string_becomes_text
    assert_equal(['"Stryker was here!"'], replacements('""'))
  end

  def test_an_empty_single_quoted_string_becomes_text
    assert_equal(['"Stryker was here!"'], replacements("''"))
  end

  def test_an_empty_percent_literal_becomes_text
    assert_equal(['"Stryker was here!"'], replacements("%q()"))
  end

  def test_the_edit_covers_the_whole_literal
    edit = edits("ok = 'a'\n").first

    assert_equal([5, 8, '""'], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_the_mutant_is_the_whole_file_with_the_string_emptied
    assert_equal(["ok = \"\"\n"], mutated("ok = 'a'\n"))
  end

  def test_an_interpolated_string_becomes_an_empty_one_as_a_whole
    assert_equal(['""'], replacements("\"Total: \#{total}\""))
  end

  def test_an_interpolated_string_that_starts_with_an_interpolation_becomes_an_empty_one
    assert_equal(['""'], replacements("\"\#{total} due\""))
  end

  def test_adjacent_literals_become_one_empty_string
    edit = edits(%("a" "b"\n)).first

    assert_equal([0, 7, '""'], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_adjacent_literals_with_an_interpolation_become_one_empty_string
    assert_equal(['""'], replacements("\"a\" \"b\#{c}\""))
  end

  def test_adjacent_empty_literals_become_text
    assert_equal(['"Stryker was here!"'], replacements(%("" '')))
  end

  def test_a_heredoc_becomes_an_empty_string_with_an_edit_that_covers_only_its_opener
    edit = edits("s = <<~TEXT\n  hello\nTEXT\n").first

    assert_equal([4, 11, '""'], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_an_interpolated_heredoc_becomes_an_empty_string_with_an_edit_that_covers_only_its_opener
    edit = edits("s = <<~TEXT\n  hello \#{name}\nTEXT\n").first

    assert_equal([4, 11, '""'], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_a_raw_heredoc_becomes_an_empty_string
    assert_equal(['""'], replacements("s = <<~'TEXT'\n  hello\nTEXT\n"))
  end

  def test_an_empty_heredoc_becomes_text
    assert_equal(['"Stryker was here!"'], replacements("s = <<~TEXT\nTEXT\n"))
  end

  def test_a_heredoc_with_a_method_call_after_it_becomes_an_empty_string
    assert_equal(['""'], replacements("s = <<~TEXT.strip\n  hello\nTEXT\n"))
  end

  def test_makes_a_mutant_for_each_string_in_the_order_of_the_tree
    assert_equal(['""', '"Stryker was here!"', '""'], replacements("f('a', '', \"b\#{c}\")"))
  end

  def test_makes_a_mutant_of_the_value_of_a_hash_pair_and_not_of_its_key
    assert_equal(["{ \"rate\" => \"\" }"], mutated(%({ "rate" => "a" })))
  end

  def test_makes_a_mutant_of_an_element_of_a_bracketed_array
    assert_equal(['""', '""'], replacements(%(["a", "b"])))
  end

  def test_makes_a_mutant_of_an_interpolated_string_as_a_whole_and_none_of_a_string_inside_it
    assert_equal(['""'], replacements("\"a \#{\"b\"} c\""))
  end

  def test_makes_a_mutant_of_a_string_with_multibyte_characters
    assert_equal(["ok = \"\"\n"], mutated("ok = 'réponse'\n"))
  end
end
