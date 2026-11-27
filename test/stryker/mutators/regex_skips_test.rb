# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/regex"
require_relative("../../support/mutator_case")

# Checks the sites that Regex makes no mutant of, and the mutants it drops,
# from its section of docs/contributors/design/mutators.md.
class RegexSkipsTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::Regex
  end

  def test_makes_no_mutant_of_a_regexp_with_interpolation
    assert_empty(edits("/^\#{prefix}\\d+$/"))
  end

  def test_makes_no_mutant_of_a_regexp_with_interpolation_that_compiles_once
    assert_empty(edits("/^\#{prefix}$/o"))
  end

  def test_makes_no_mutant_of_a_string_with_interpolation_given_to_regexp_new
    assert_empty(edits("Regexp.new(\"^\#{prefix}$\")"))
  end

  def test_makes_no_mutant_of_a_pattern_that_has_nothing_to_change
    assert_empty(edits("/abc/\n/(?:a|b)c/\nRegexp.new('abc')\n"))
  end

  def test_makes_no_mutant_of_a_string_that_is_not_the_first_argument_of_regexp_new
    assert_empty(edits('Regexp.new(source, "^a")'))
  end

  def test_makes_no_mutant_of_a_string_given_to_another_class_or_method
    assert_empty(edits("Pattern.new('^a')\nTools::Regexp.new('^a')\nRegexp.escape('^a')\nRegexp.union('^a')\n"))
  end

  def test_makes_no_mutant_of_a_string_that_is_not_given_to_a_call_of_new
    assert_empty(edits("x = '^a'\nputs('^a')\n"))
  end

  def test_makes_no_mutant_of_a_regexp_that_stands_as_a_condition
    assert_empty(edits("puts(1) if /^a/"))
  end

  def test_reads_an_extended_regexp_without_its_comments
    assert_empty(edits("/a # ^b$ and \\d+\n/x"))
  end

  def test_drops_a_mutant_that_is_not_a_valid_regexp
    # A negative lookbehind can't hold a group that captures.
    assert_empty(replacements("/(?<=(a))b/"))
  end

  def test_makes_the_other_mutants_of_a_pattern_that_has_one_dropped
    assert_equal(["/(?<=(a))b/", '/\A(?<=(a))b/'], replacements("/^(?<=(a))b/"))
  end

  def test_compiles_a_mutant_without_the_warnings_that_ruby_gives_about_it
    # Removing one star of a***, the three that Ruby calls nested, leaves a**, which Ruby compiles with a warning.
    output = capture_io { assert_equal(["/a**/"], replacements("/a***/").uniq) }

    assert_equal(["", ""], output)
  end

  def test_compiles_a_mutant_with_the_flags_of_the_literal
    # The comment holds a parenthesis that only the x flag makes harmless.
    assert_equal(["/a # (\n/x", "/\\Aa # (\n/x"], replacements("/^a # (\n/x"))
  end

  def test_compiles_a_mutant_with_the_options_of_regexp_new
    mutated = replacements('Regexp.new("^a # (\n", Regexp::EXTENDED)')

    assert_equal(['"a # (\\n"', '"\\\\Aa # (\\n"'], mutated)
  end

  def test_reads_the_extended_option_of_regexp_new_in_each_form_it_is_given_in
    options = [
      "Regexp::EXTENDED",
      "Regexp::IGNORECASE | Regexp::EXTENDED",
      "::Regexp::EXTENDED",
      '"x"',
      '"ix"',
      "2",
      "3",
]

    assert_equal([2] * options.size, options.map { |text| edits("Regexp.new(\"^a # (\\n\", #{text})").size })
  end

  def test_reads_the_other_options_of_regexp_new_in_each_form_it_is_given_in
    options = ["nil", "false", "true", "0", "1", '"i"', "Regexp::MULTILINE"]

    assert_equal([2] * options.size, options.map { |text| edits("Regexp.new('^a', #{text})").size })
  end

  def test_makes_no_mutant_of_regexp_new_with_options_that_the_source_does_not_give
    sources = [
      'Regexp.new("^a", options)',
      "opts = 1\nRegexp.new('^a', opts)",
      'Regexp.new("^a", Regexp::EXTENDED | opts)',
]

    assert_equal([0] * sources.size, sources.map { |source| edits(source).size })
  end

  def test_makes_the_mutants_of_regexp_new_that_is_given_a_timeout_and_no_options
    assert_equal(2, edits('Regexp.new("^a", timeout: 1)').size)
  end
end
