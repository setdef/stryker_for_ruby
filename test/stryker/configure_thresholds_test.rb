# frozen_string_literal: true

require_relative("../support/config_project")
require_relative("../test_helper")

# Checks that Configure refuses a high threshold below the low one, as
# StrykerJS does, and says where each of the two values came from.
class ConfigureThresholdsTest < Minitest::Test
  include ConfigProject

  def test_a_file_with_high_below_low_is_refused_naming_both_options
    message = refusal({ "stryker.config.json": '{ "thresholds": { "high": 50, "low": 70 } }' })

    assert_equal(
      %("thresholds.high" in stryker.config.json is 50, which is below "thresholds.low" in stryker.config.json (70). ) +
        %("thresholds.high" can't be below "thresholds.low".),
      message
    )
  end

  def test_a_high_below_the_default_low_is_refused_naming_the_default
    message = refusal({ "stryker.config.yml": "thresholds:\n  high: 50\n" })

    assert_equal(
      %("thresholds.high" in stryker.config.yml is 50, which is below "thresholds.low" by default (60). ) +
        %("thresholds.high" can't be below "thresholds.low".),
      message
    )
  end

  def test_a_low_above_the_default_high_is_refused_naming_the_default
    message = refusal({}, options: { :"thresholds.low" => 90 })

    assert_equal(
      %("thresholds.high" by default is 80, which is below "--thresholds.low" on the command line (90). ) +
        %("thresholds.high" can't be below "thresholds.low".),
      message
    )
  end

  def test_the_flag_that_replaces_the_files_high_is_the_one_checked
    files = { "stryker.config.json": '{ "thresholds": { "high": 50 } }' }

    assert_equal(95, configure(files, options: { :"thresholds.high" => 95 }).threshold_high)
  end

  def test_the_flag_that_replaces_the_files_low_is_the_one_checked
    files = { "stryker.config.json": '{ "thresholds": { "low": 90 } }' }

    assert_equal(10, configure(files, options: { :"thresholds.low" => 10 }).threshold_low)
  end

  def test_equal_thresholds_are_accepted
    config = configure({}, options: { :"thresholds.high" => 70, :"thresholds.low" => 70 })

    assert_equal([70, 70], [config.threshold_high, config.threshold_low])
  end

  def test_a_value_out_of_range_is_the_only_problem_reported
    message = refusal({}, options: { :"thresholds.low" => 150 })

    assert_equal(
      '"--thresholds.low" on the command line takes a whole number from 0 to 100, but its value is 150.',
      message
    )
  end

  # The report schema gives thresholds.high and thresholds.low the type integer.
  def test_a_fractional_high_in_a_file_is_refused_as_not_a_whole_number
    message = refusal({ "stryker.config.json": '{ "thresholds": { "high": 80.5 } }' })

    assert_equal(
      '"thresholds.high" in stryker.config.json takes a whole number from 0 to 100, but its value is 80.5.',
      message
    )
  end

  def test_a_fractional_low_on_the_command_line_is_refused_as_not_a_whole_number
    message = refusal({}, options: { :"thresholds.low" => 70.5 })

    assert_equal(
      '"--thresholds.low" on the command line takes a whole number from 0 to 100, but its value is 70.5.',
      message
    )
  end

  def test_a_number_with_a_zero_fraction_is_a_whole_number
    config = configure({}, options: { :"thresholds.high" => 90.0, :"thresholds.low" => 70.0 })

    assert_equal([90.0, 70.0], [config.threshold_high, config.threshold_low])
  end

  def test_a_number_with_a_zero_fraction_is_held_as_an_integer
    config = configure({}, options: { :"thresholds.high" => 90.0, :"thresholds.low" => 70.0 })

    assert_equal([Integer, Integer], [config.threshold_high.class, config.threshold_low.class])
  end

  def test_the_break_threshold_still_takes_a_fraction
    assert_in_delta(80.5, configure({}, options: { :"thresholds.break" => 80.5 }).threshold_break, 0.001)
  end

  def test_a_value_of_the_wrong_type_is_the_only_problem_reported
    message = refusal({}, options: { :"thresholds.high" => "lots", :"thresholds.low" => 70 })

    assert_equal(
      '"--thresholds.high" on the command line takes a whole number from 0 to 100, but its value is "lots".',
      message
    )
  end
end
