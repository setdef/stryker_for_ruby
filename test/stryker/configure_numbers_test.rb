# frozen_string_literal: true

require_relative("../support/config_project")
require_relative("../test_helper")

# Checks that the options that take a number accept a fraction as well as a
# whole number, as StrykerJS's schema does, and refuse a number that is not
# finite.
class ConfigureNumbersTest < Minitest::Test
  include ConfigProject

  def test_a_fraction_in_a_file_is_kept_as_it_is
    json = '{ "thresholds": { "high": 90.5, "low": 70.25, "break": 80.5 }, "timeoutMS": 2500.5 }'
    config = configure({ "stryker.config.json": json })

    assert_equal(
      [90.5, 70.25, 80.5, 2500.5],
      [config.threshold_high, config.threshold_low, config.threshold_break, config.timeout_ms]
    )
  end

  def test_a_whole_number_stays_a_whole_number
    config = configure({}, options: { :"thresholds.break" => 80, :timeoutMS => 2500 })

    assert_equal([Integer, Integer], [config.threshold_break.class, config.timeout_ms.class])
  end

  def test_a_number_that_is_not_finite_is_refused_for_every_option_that_takes_a_number
    names = %i[timeoutMS timeoutFactor thresholds.high thresholds.low thresholds.break]
    refused = names.to_h do |name|
      [name, [Float::INFINITY, Float::NAN].map { |value| refusal({}, options: { name => value }).lines.count }]
    end

    assert_equal(names.to_h { |name| [name, [1, 1]] }, refused)
  end

  def test_a_factor_that_is_not_finite_is_refused_naming_the_value
    messages = [Float::INFINITY, Float::NAN].map { |value| refusal({}, options: { :timeoutFactor => value }) }

    assert_equal(
      [
        '"--timeout-factor" on the command line takes a number of 0 or more, but its value is Infinity.',
        '"--timeout-factor" on the command line takes a number of 0 or more, but its value is NaN.',
      ],
      messages
    )
  end

  def test_a_whole_number_too_big_for_a_float_is_refused_as_infinite
    message = refusal({}, options: { :timeoutFactor => 10 ** 400 })

    assert_includes(message, '"--timeout-factor" on the command line takes a number of 0 or more, but its value is 10')
  end

  def test_a_whole_timeout_too_big_for_a_float_is_refused_as_infinite
    message = refusal({}, options: { :timeoutMS => 10 ** 400 })

    assert_includes(message, '"--timeout-ms" on the command line takes a number of milliseconds, 0 or more')
  end
end
