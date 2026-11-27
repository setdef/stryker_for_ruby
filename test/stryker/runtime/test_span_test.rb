# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/runtime/test_span"

# Checks that a test span times the first start to the last finish on the
# monotonic clock.
class TestSpanTest < Minitest::Test
  def test_the_span_counts_from_the_first_start_to_the_last_finish
    times = [1.0, 5.0, 9.0, 12.0]
    span = Stryker::Runtime::TestSpan.new(-> { times.shift })
    span.started
    span.finished
    span.started
    span.finished

    assert_in_delta(8.0, span.duration_ms)
  end

  def test_a_span_with_a_start_and_no_finish_is_empty
    span = Stryker::Runtime::TestSpan.new(-> { 4.0 })
    span.started

    assert_in_delta(0.0, span.duration_ms)
  end

  def test_the_default_clock_never_goes_back
    span = Stryker::Runtime::TestSpan.new
    span.started
    span.finished

    assert_operator(span.duration_ms, :>=, 0.0)
  end
end
