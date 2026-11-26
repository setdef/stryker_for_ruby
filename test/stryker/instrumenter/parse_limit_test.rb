# frozen_string_literal: true

require_relative("../../test_helper")
require "minitest/mock"
require "stryker/instrumenter/parse_limit"

# Checks the time that a read from a parse worker may take.
class ParseLimitTest < Minitest::Test
  Limit = Stryker::Instrumenter::ParseLimit
  SOURCE = "x = 1\n"
  private_constant(:Limit, :SOURCE)

  # The limit when the clock says that the parse in this process took
  # +seconds+.
  def limit_for_a_parse_of(seconds)
    ticks = [10.0, seconds + 10.0].each
    Process.stub(:clock_gettime, -> (*) { ticks.next }) { Limit.seconds(SOURCE) }
  end

  def test_a_parse_that_takes_little_time_gets_the_floor
    assert_in_delta(Limit::FLOOR, limit_for_a_parse_of(0.01))
  end

  def test_a_parse_that_takes_long_gets_the_factor_times_its_time
    assert_in_delta(Limit::FACTOR * 2.5, limit_for_a_parse_of(2.5))
  end

  def test_it_parses_the_source
    parsed = []
    Stryker::Instrumenter::Syntax.stub(:parse, -> (source) { parsed << source }) { Limit.seconds(SOURCE) }

    assert_equal([SOURCE], parsed)
  end
end
