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

  def test_leaves_out_the_first_code_units
    tails = [0, 1, 3, 4].map { |count| Stryker::Reporters::CodeUnits.tail(EMOJI, count) }

    assert_equal([EMOJI, "\u{1F600}b", "b", ""], tails)
  end
end
