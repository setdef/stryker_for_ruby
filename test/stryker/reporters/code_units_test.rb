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

  def test_leaves_out_the_first_code_units
    tails = [0, 1, 3, 4].map { |count| Stryker::Reporters::CodeUnits.tail(EMOJI, count) }

    assert_equal([EMOJI, "\u{1F600}b", "b", ""], tails)
  end
end
