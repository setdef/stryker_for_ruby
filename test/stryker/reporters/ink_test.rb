# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/reporters/ink"

# Checks that ink wraps text in the escape sequences of the colors the
# reporters use, and leaves it as it is when color is off.
class InkTest < Minitest::Test
  def test_wraps_text_in_the_escape_sequence_of_a_color
    ink = Stryker::Reporters::Ink.new(enabled: true)

    assert_equal(
      ["\e[31mx\e[39m", "\e[32mx\e[39m", "\e[33mx\e[39m", "\e[36mx\e[39m", "\e[90mx\e[39m"],
      %i[red green yellow cyan grey].map { |color| ink.paint(color, "x") }
    )
  end

  def test_leaves_text_as_it_is_when_color_is_off
    assert_equal("x", Stryker::Reporters::Ink.new(enabled: false).paint(:red, "x"))
  end

  def test_refuses_a_color_it_does_not_have_even_when_color_is_off
    assert_raises(ArgumentError) { Stryker::Reporters::Ink.new(enabled: false).paint(:magenta, "x") }
  end
end
