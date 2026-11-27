# frozen_string_literal: true

require_relative("../../test_helper")
require "prism"
require "stryker/mutators/regex"
require "stryker/mutators/walk"
require_relative("../../support/mutator_case")

# Checks that Regex refuses a pattern that regexp_parser can't read, and that
# a walk turns the refusal into one warning with the file and the line.
class RegexUnreadableTest < Minitest::Test
  include MutatorCase

  WARNING = %r{\Alib/a\.rb:(\d+): warning: Stryker \(for Ruby\) can't read this regular expression, .+\n\z}
  private_constant(:WARNING)

  def mutator
    Stryker::Mutators::Regex
  end

  # The walk's mutants and what it wrote to standard error.
  def walk(source)
    mutants = nil
    _out, err = capture_io do
      mutants = Stryker::Mutators::Walk.new(file: "lib/a.rb", result: Prism.parse(source), mutators: [mutator]).mutants
    end
    [mutants, err]
  end

  def test_refuses_a_pattern_that_regexp_parser_cannot_read
    error = assert_raises(Stryker::Mutators::Unreadable) { edits('Regexp.new("(")') }

    assert_match(
      /\AStryker \(for Ruby\) can't read this regular expression, so it makes no mutant of it: .+\.\z/,
      error.message
    )
  end

  def test_a_walk_writes_one_warning_with_the_file_and_the_line
    mutants, err = walk("x = 1\nRegexp.new(\"(\")\n")

    assert_empty(mutants)
    assert_equal(["2"], err.lines.map { |line| line[WARNING, 1] })
  end

  def test_a_warning_shows_an_invalid_byte_of_the_pattern_as_an_escape
    _mutants, err = walk("Regexp.new(\"\\xff^a\")\n")

    assert_predicate(err, :valid_encoding?)
    assert_includes(err, '\xFF')
  end

  def test_a_warning_shows_a_terminal_escape_character_of_the_pattern_as_an_escape
    _mutants, err = walk("Regexp.new(\"\\e[31m(\")\n")

    refute_includes(err, "\e")
    assert_includes(err, '\e[31m(')
  end

  def test_a_walk_goes_on_to_the_other_patterns
    mutants, err = walk("Regexp.new(\"(\")\n/^a/\nRegexp.new(\"[\")\n")

    assert_equal(["/a/", '/\Aa/'], mutants.map(&:replacement))
    assert_equal(%w[1 3], err.lines.map { |line| line[WARNING, 1] })
  end

  def test_a_walk_writes_nothing_when_every_pattern_is_readable
    mutants, err = walk("/^a/\n")

    assert_equal([2, ""], [mutants.size, err])
  end
end
