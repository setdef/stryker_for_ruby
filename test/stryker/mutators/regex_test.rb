# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/regex"
require_relative("../../support/mutator_case")

# Checks the pairs of Regex, and the descriptions of its mutants, from its
# section of docs/contributors/design/mutators.md.
class RegexTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::Regex
  end

  # The patterns that the mutants of the literal /text/ have. The offsets of
  # a pattern's nodes hold only when regexp_parser's tree gives the pattern
  # back, so each pattern here has to round-trip.
  def patterns(text, flags = "")
    assert_equal(text, Regexp::Parser.parse(text, options: Regexp::EXTENDED).to_s)
    replacements("/#{text}/#{flags}").map { |literal| literal.delete_prefix("/").delete_suffix("/#{flags}") }
  end

  def test_is_named_for_the_report
    assert_equal("Regex", mutator.name)
  end

  def test_mutates_a_regexp_literal_in_a_case_in_pattern_as_it_mutates_one_anywhere
    pattern = "case x\nin /^a/ then 1\nend"

    assert_equal(["/a/", '/\Aa/'], replacements(pattern))
    assert_equal(replacements("/^a/"), replacements(pattern))
  end

  def test_an_anchor_is_removed_in_each_of_its_spellings
    assert_equal(%w[a a a a a], ["^a", "a$", '\Aa', 'a\z', 'a\Z'].map { |text| patterns(text).first })
  end

  def test_a_line_anchor_becomes_a_string_anchor
    assert_equal(['\Aa', 'a\z'], [patterns("^a").last, patterns("a$").last])
  end

  def test_a_string_anchor_gets_only_its_removal
    assert_equal([%w[a], %w[a], %w[a]], ['\Aa', 'a\z', 'a\Z'].map { |text| patterns(text) })
  end

  def test_a_character_class_is_negated
    assert_equal(["[^aeiou]"], patterns("[aeiou]"))
  end

  def test_a_negated_character_class_is_not_negated
    assert_equal(["[aeiou]"], patterns("[^aeiou]"))
  end

  def test_a_character_class_inside_a_character_class_is_negated_too
    assert_equal(["[^a-z&&[^b]]", "[a-z&&[b]]"], patterns("[a-z&&[^b]]"))
  end

  def test_a_shorthand_class_is_negated
    assert_equal(%w[\D \S \W], %w[\d \s \w].flat_map { |text| patterns(text) })
  end

  def test_a_negated_shorthand_class_is_not_negated
    assert_equal(%w[\d \s \w], %w[\D \S \W].flat_map { |text| patterns(text) })
  end

  def test_a_shorthand_class_in_a_character_class_is_negated
    assert_equal(['[^\d]', '[\D]'], patterns('[\d]'))
  end

  def test_a_property_is_negated
    assert_equal(['\P{Alpha}'], patterns('\p{Alpha}'))
  end

  def test_a_negated_property_is_not_negated
    assert_equal(['\p{Alpha}', '\p{Alpha}'], patterns('\P{Alpha}') + patterns('\p{^Alpha}'))
  end

  def test_a_quantifier_is_removed
    assert_equal(%w[abc abc abc abc], ["ab+c", "ab?c", "ab*c", "ab{2,4}c"].map { |text| patterns(text).first })
  end

  def test_a_lazy_or_possessive_quantifier_is_removed_whole
    assert_equal(%w[ab ab], ["ab+?", "ab*+"].map { |text| patterns(text).first })
  end

  def test_the_quantifier_of_a_group_goes_and_the_group_stays
    assert_equal(["(ab)"], patterns("(ab)+"))
  end

  def test_a_lookahead_is_negated_in_both_directions
    assert_equal(["a(?!b)", "a(?=b)"], patterns("a(?=b)") + patterns("a(?!b)"))
  end

  def test_a_lookbehind_is_negated_in_both_directions
    assert_equal(["(?<!a)b", "(?<=a)b"], patterns("(?<=a)b") + patterns("(?<!a)b"))
  end

  def test_makes_the_mutants_of_a_pattern_in_the_order_of_its_tree
    assert_equal(['\d+$', '\A\d+$', '^\D+$', '^\d$', '^\d+', '^\d+\z'], patterns('^\d+$'))
  end

  def test_makes_no_mutant_of_a_pattern_with_nothing_to_change
    assert_empty(patterns("abc"))
  end

  def test_makes_no_mutant_of_the_character_types_that_are_not_shorthand_classes
    assert_empty(patterns('\h\H\R\X'))
  end

  def test_makes_no_mutant_of_word_boundaries_groups_and_alternations
    assert_empty(patterns('\b\B(?:a|b)(?<n>c)\k<n>'))
  end

  def test_the_mutant_is_the_whole_file_with_the_literal_changed
    assert_equal(["ok = /\\D+/.match?(s)\n", "ok = /\\d/.match?(s)\n"], mutated("ok = /\\d+/.match?(s)\n"))
  end

  def test_the_edit_covers_the_whole_literal
    edit = edits("ok = /^a/i\n").first

    assert_equal([5, 10, "/a/i"], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_keeps_the_flags_and_the_delimiters
    assert_equal(
      ["/a/imx", "%r{a}i", "%r[a]"],
      ["/^a/imx", "%r{^a}i", "%r[^a]"].map do |source|
        replacements(source).first
      end
    )
  end

  def test_keeps_an_escaped_slash
    assert_equal(['/a\/b/'], replacements('/^a\/b/').first(1))
  end
end
