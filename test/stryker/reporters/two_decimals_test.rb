# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/reporters/two_decimals"

# Checks that numbers are written as JavaScript's toFixed(2) writes them, which
# is how StrykerJS writes a score: the exact value of the number decides the
# last digit, and an exact half rounds up.
class TwoDecimalsTest < Minitest::Test
  def test_writes_two_decimals
    written = [0.0, 33.333, 100.0, 2 / 3.0].map { |number| Stryker::Reporters::TwoDecimals.of(number) }

    assert_equal(["0.00", "33.33", "100.00", "0.67"], written)
  end

  def test_rounds_an_exact_half_up
    written = [0.125, 0.375].map { |number| Stryker::Reporters::TwoDecimals.of(number) }

    assert_equal(["0.13", "0.38"], written)
  end

  def test_rounds_by_the_exact_value_of_the_number_not_by_how_it_prints
    assert_equal("2.67", Stryker::Reporters::TwoDecimals.of(2.675))
  end

  def test_writes_nan_as_nan
    assert_equal("NaN", Stryker::Reporters::TwoDecimals.of(Float::NAN))
  end
end
