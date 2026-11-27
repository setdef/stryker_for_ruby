# frozen_string_literal: true

require_relative("../../support/progress_run")
require "stryker/reporters/ink"
require "stryker/reporters/progress_line"
require "stryker/reporters/progress_tally"

# Checks the two forms of the progress line against the lines that StrykerJS's
# progress reporters write: with a bar for a terminal, and without for a log.
class ProgressLineTest < Minitest::Test
  PLAIN_RUN = "Mutation testing 50% (elapsed: ~2m, remaining: ~2m) 1/2 tested (1 survived, 0 timed out)"
  private_constant(:PLAIN_RUN)

  def line(elapsed: 150.0, color: false, status: "Survived")
    tally = Stryker::Reporters::ProgressTally.new({ 1 => 30.0, 2 => 30.0 })
    tally.record(ProgressRun.tested(1, status).result)
    Stryker::Reporters::ProgressLine.new(tally, elapsed:, ink: Stryker::Reporters::Ink.new(enabled: color))
  end

  def test_the_plain_form_gives_the_percent_the_times_and_the_counts
    assert_equal(PLAIN_RUN, line.plain)
  end

  def test_the_bar_form_fills_a_bar_of_fifty_characters_to_the_work_done
    expected = "Mutation testing  [#{'=' * 25}#{' ' * 25}] 50% (elapsed: ~2m, remaining: ~2m) " \
      "1/2 Mutants tested (1 survived, 0 timed out)"

    assert_equal(expected, line.bar(200))
  end

  def test_the_bar_is_as_wide_as_the_rest_of_the_line_leaves_room_for
    text = line.bar(110)

    assert_equal([110, 10], [text.length, text[/\[(.*)\]/, 1].length])
  end

  def test_the_bar_has_no_width_when_the_rest_of_the_line_fills_the_terminal
    assert_includes(line.bar(40), "[] 50%")
  end

  def test_says_that_the_time_left_is_not_available_before_any_work_is_done
    fresh = Stryker::Reporters::ProgressLine.new(
      Stryker::Reporters::ProgressTally.new({ 1 => 1.0 }),
      elapsed: 0.5,
      ink: Stryker::Reporters::Ink.new(enabled: false)
    )

    assert_equal("Mutation testing 0% (elapsed: <1m, remaining: n/a) 0/1 tested (0 survived, 0 timed out)", fresh.plain)
  end

  def test_paints_the_filled_bar_green_and_a_count_above_zero_when_the_ink_is_on
    painted = line(color: true).bar(200)

    codes = ["\e[32m#{'=' * 25}\e[39m", "\e[31m1 survived\e[39m", "\e[33m"]

    assert_equal([true, true, false], codes.map { |code| painted.include?(code) })
  end

  def test_paints_a_count_of_timeouts_yellow
    assert_includes(line(color: true, status: "Timeout").plain, "\e[33m1 timed out\e[39m")
  end
end
