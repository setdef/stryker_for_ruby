# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/reporters/duration_text"

# Checks that a time is written as StrykerJS's progress reporters write it:
# whole minutes, with hours from an hour on, and less than a minute as such.
class DurationTextTest < Minitest::Test
  def test_a_time_under_a_minute_is_less_than_a_minute
    assert_equal(["<1m", "<1m"], [0, 59].map { |seconds| Stryker::Reporters::DurationText.of(seconds) })
  end

  def test_a_time_from_a_minute_on_is_whole_minutes_rounded_down
    written = [60, 119, 3599].map { |seconds| Stryker::Reporters::DurationText.of(seconds) }

    assert_equal(["~1m", "~1m", "~59m"], written)
  end

  def test_a_time_from_an_hour_on_has_hours_and_minutes
    written = [3600, 3660, 93_840].map { |seconds| Stryker::Reporters::DurationText.of(seconds) }

    assert_equal(["~1h 0m", "~1h 1m", "~26h 4m"], written)
  end
end
