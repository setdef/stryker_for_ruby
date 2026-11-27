# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/reporters/code_units"

# Checks that text is cut at UTF-16 code units, where a character outside the
# Basic Multilingual Plane takes two.
class CodeUnitsTest < Minitest::Test
  EMOJI = "a\u{1F600}b"
  private_constant(:EMOJI)

  def test_keeps_the_first_code_units
    heads = [0, 1, 3, 4].map { |count| Stryker::Reporters::CodeUnits.head(EMOJI, count) }

    assert_equal(["", "a", "a\u{1F600}", EMOJI], heads)
  end

  def test_counts_the_code_units_of_text
    widths = ["", "a", EMOJI, "\u00E9\u{1F600}"].map { |text| Stryker::Reporters::CodeUnits.width(text) }

    assert_equal([0, 1, 4, 3], widths)
  end

  def test_counts_two_for_an_emoji_made_of_several_characters
    family = "\u{1F468}\u200D\u{1F469}\u200D\u{1F467}"
    flag = "\u{1F1EB}\u{1F1F7}"
    heart = "\u2764\uFE0F"
    keycap = "1\uFE0F\u20E3"

    assert_equal([2, 2, 2, 2], [family, flag, heart, keycap].map { |text| Stryker::Reporters::CodeUnits.width(text) })
  end

  def test_counts_two_for_the_subdivision_flags_that_are_tag_sequences
    england = "\u{1F3F4}\u{E0067}\u{E0062}\u{E0065}\u{E006E}\u{E0067}\u{E007F}"
    scotland = "\u{1F3F4}\u{E0067}\u{E0062}\u{E0073}\u{E0063}\u{E0074}\u{E007F}"
    wales = "\u{1F3F4}\u{E0067}\u{E0062}\u{E0077}\u{E006C}\u{E0073}\u{E007F}"

    assert_equal([2, 2, 2], [england, scotland, wales].map { |text| Stryker::Reporters::CodeUnits.width(text) })
  end

  def test_counts_the_tags_of_a_subdivision_that_emoji_regex_has_no_flag_for
    texas = "\u{1F3F4}\u{E0075}\u{E0073}\u{E0074}\u{E0078}\u{E007F}"

    assert_equal(12, Stryker::Reporters::CodeUnits.width(texas))
  end

  def test_leaves_out_the_first_code_units
    tails = [0, 1, 3, 4].map { |count| Stryker::Reporters::CodeUnits.tail(EMOJI, count) }

    assert_equal([EMOJI, "\u{1F600}b", "b", ""], tails)
  end
end
