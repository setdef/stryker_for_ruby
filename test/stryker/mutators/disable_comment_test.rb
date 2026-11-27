# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/disable_comment"

# Checks the grammar of the disable comment, which is StrykerJS's pattern
# with Ruby's `#` in front, as the section "The disable comment" of
# docs/contributors/design/mutators.md says.
class DisableCommentTest < Minitest::Test
  # Stands in for the lines of a file: the line of the next code is +next_code+.
  Code = Struct.new(:next_code) do
    def after(_line)
      next_code
    end
  end
  private_constant(:Code)

  # Stands in for a candidate: the line its site starts on and its mutator's name.
  Candidate = Struct.new(:line, :mutator_name)
  private_constant(:Candidate)

  def covers?(comment, name, line)
    comment.covers?(Candidate.new(line, name))
  end

  def parse(text, line: 3, next_code: 4)
    Stryker::Mutators::DisableComment.parse(text, line, Code.new(next_code))
  end

  def test_takes_a_list_of_names_and_a_reason_after_a_colon
    comment = parse(" Stryker disable next-line EqualityOperator, StringLiteral: both are equivalent here")

    assert_equal(%w[EqualityOperator StringLiteral], comment.names.values)
    assert_equal("both are equivalent here", comment.reason)
  end

  def test_gives_the_default_reason_when_the_comment_has_none
    assert_equal("Ignored using a comment", parse(" Stryker disable all").reason)
  end

  def test_gives_the_default_reason_when_the_reason_is_only_whitespace
    assert_equal("Ignored using a comment", parse(" Stryker disable all:  ").reason)
  end

  def test_keeps_a_colon_inside_the_reason
    assert_equal("see: the ticket", parse(" Stryker disable all: see: the ticket").reason)
  end

  def test_a_restore_comment_has_no_reason
    assert_nil(parse(" Stryker restore all: why").reason)
  end

  def test_accepts_no_space_after_the_hash_and_one_whitespace_character
    assert_equal(["all"], parse("Stryker disable all").names.values)
    assert_equal(["all"], parse("\tStryker disable all").names.values)
  end

  def test_is_an_ordinary_comment_when_anything_comes_before_stryker
    assert_nil(parse("  Stryker disable all"))
    assert_nil(parse(" @stryker disable all"))
    assert_nil(parse(" See Stryker disable all"))
  end

  def test_is_an_ordinary_comment_when_stryker_has_a_lowercase_s
    assert_nil(parse(" stryker disable all"))
  end

  def test_is_an_ordinary_comment_without_a_list_of_names
    assert_nil(parse(" Stryker disable"))
    assert_nil(parse(" Stryker enable all"))
  end

  def test_reads_next_line_with_a_hyphen_only
    assert_equal(["next line EqualityOperator"], parse(" Stryker disable next line EqualityOperator").names.values)
  end

  def test_a_comment_without_next_line_covers_the_rest_of_the_file_from_its_own_line
    comment = parse(" Stryker disable all", line: 3)

    assert_equal([false, true, true], [2, 3, 9_999].map { |line| covers?(comment, "Nines", line) })
  end

  def test_a_next_line_comment_covers_only_the_next_line_that_holds_code
    comment = parse(" Stryker disable next-line all", line: 3, next_code: 6)

    assert_equal([false, true, false], [3, 6, 7].map { |line| covers?(comment, "Nines", line) })
  end

  def test_a_next_line_comment_with_no_code_after_it_covers_nothing
    comment = parse(" Stryker disable next-line all", next_code: nil)

    assert_equal([false, false], [3, 4].map { |line| covers?(comment, "Nines", line) })
  end

  def test_covers_the_mutators_it_lists_with_any_letter_case
    comment = parse(" Stryker disable BooleanLiteral , equalityoperator")
    covered = %w[BOOLEANLITERAL EqualityOperator StringLiteral].map { |name| covers?(comment, name, 5) }

    assert_equal([true, true, false], covered)
  end

  def test_all_covers_every_mutator_with_any_letter_case
    assert(covers?(parse(" Stryker disable ALL"), "StringLiteral", 5))
  end

  def test_lists_the_names_that_no_mutator_has
    comment = parse(" Stryker disable BooleanLiteral, Nope,, all")

    assert_equal(["Nope", ""], comment.unknown(%w[booleanliteral stringliteral]))
  end
end
