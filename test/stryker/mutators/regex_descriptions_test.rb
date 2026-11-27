# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/regex"
require_relative("../../support/mutator_case")

# Checks the descriptions of the mutants of Regex, and the pattern given to
# Regexp.new, from its section of docs/contributors/design/mutators.md.
class RegexDescriptionsTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::Regex
  end

  def descriptions(source)
    edits(source).map(&:description)
  end

  def test_counts_offsets_in_characters
    assert_equal(['Anchor "^" was removed at offset 1.'], descriptions("/é^é/").first(1))
  end

  def test_describes_the_mutants_of_a_pattern
    expected = [
      'Anchor "^" was removed at offset 0.',
      'Anchor "^" was replaced with "\A" at offset 0.',
      'Character class shorthand "\d" was replaced with "\D" at offset 1.',
      'Quantifier "+" was removed at offset 3.',
      'Anchor "$" was removed at offset 4.',
      'Anchor "$" was replaced with "\z" at offset 4.',
    ]

    assert_equal(expected, descriptions('/^\d+$/'))
  end

  def test_describes_a_negated_character_class
    assert_equal(['Character class "[aeiou]" was replaced with "[^aeiou]" at offset 0.'], descriptions("/[aeiou]/"))
  end

  def test_describes_a_negated_property
    assert_equal(['Property "\p{Alpha}" was replaced with "\P{Alpha}" at offset 0.'], descriptions('/\p{Alpha}/'))
  end

  def test_describes_a_negated_lookaround
    assert_equal(['Lookaround "(?=b)" was replaced with "(?!b)" at offset 1.'], descriptions("/a(?=b)/"))
  end

  def test_describes_a_removed_quantifier_whole
    assert_equal(['Quantifier "{2,4}" was removed at offset 2.'], descriptions("/ab{2,4}/"))
    assert_equal(['Quantifier "+?" was removed at offset 1.'], descriptions("/a+?/"))
  end

  def test_describes_a_removed_string_anchor
    assert_equal(['Anchor "\A" was removed at offset 0.'], descriptions('/\Aa/'))
  end

  def test_a_pattern_given_to_regexp_new_is_mutated
    assert_equal(['Regexp.new("a")'], mutated('Regexp.new("^a")').first(1))
  end

  def test_the_edit_of_regexp_new_covers_the_string_and_writes_the_pattern_as_a_string_literal
    edit = edits('Regexp.new(\'^\d+\')').first(2)

    assert_equal(['"\\\\d+"', '"\\\\A\\\\d+"'], edit.map(&:replacement))
    assert_equal([11, 17], [edit.first.start_offset, edit.first.end_offset])
  end

  def test_a_pattern_with_a_double_colon_receiver_is_mutated
    assert_equal(['::Regexp.new("")'], mutated('::Regexp.new("^")').first(1))
  end

  def test_the_mutants_of_regexp_new_have_descriptions
    assert_equal(['Anchor "^" was removed at offset 0.'], descriptions('Regexp.new("^a")').first(1))
  end

  def test_regexp_new_keeps_its_other_arguments
    assert_equal(['Regexp.new("a", Regexp::IGNORECASE)'], mutated('Regexp.new("^a", Regexp::IGNORECASE)').first(1))
  end
end
