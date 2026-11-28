# frozen_string_literal: true

require_relative("../../test_helper")
require "minitest"
require "stryker/test_runners/minitest_runner/scrubbing_filter"

# How the filter that the Minitest adapter puts in front of Minitest's
# backtrace filter reads the lines of a backtrace, and how it is put there and
# taken away.
class MinitestScrubbingFilterTest < Minitest::Test
  ScrubbingFilter = Stryker::TestRunners::MinitestRunner::ScrubbingFilter
  private_constant(:ScrubbingFilter)

  # Stands in for Minitest's filter, which matches each line with a regexp.
  class Matching
    def filter(lines)
      lines.grep(/\A\S+_test/)
    end
  end

  # Stands in for the filter that was in place, and keeps the lines it is given.
  class Recording
    attr_reader :seen

    def initialize
      @seen = []
    end

    def filter(lines)
      @seen.concat(lines)
    end
  end

  def test_a_line_with_a_byte_that_is_not_valid_utf8_reaches_the_wrapped_filter_with_the_byte_replaced
    kept = ScrubbingFilter.new(Matching.new).filter(["test/caf\xE9_test.rb:3:in 'test_a'", "lib/caf\xE9.rb:1"])

    assert_equal(["test/caf�_test.rb:3:in 'test_a'"], kept)
  end

  def test_a_line_that_is_valid_utf8_reaches_the_wrapped_filter_as_it_is
    kept = ScrubbingFilter.new(Matching.new).filter(["test/café_test.rb:3", "lib/a.rb:1"])

    assert_equal(["test/café_test.rb:3"], kept)
  end

  def test_around_gives_the_block_the_filter_wrapped_and_returns_the_blocks_value
    original = Minitest.backtrace_filter
    inside = nil
    value = ScrubbingFilter.around do
      inside = Minitest.backtrace_filter
      :done
    end

    assert_equal([:done, ScrubbingFilter, true], [value, inside.class, original != inside])
  end

  def test_around_puts_the_filter_back_afterwards_and_when_the_block_raises
    original = Minitest.backtrace_filter
    ScrubbingFilter.around { :done }
    after_return = Minitest.backtrace_filter
    assert_raises(ArgumentError) { ScrubbingFilter.around { raise(ArgumentError) } }

    assert_same(original, after_return)
    assert_same(original, Minitest.backtrace_filter)
  end

  def test_the_wrapped_filter_is_the_one_that_was_in_place
    original = Minitest.backtrace_filter
    recording = Recording.new
    Minitest.backtrace_filter = recording
    ScrubbingFilter.around { Minitest.backtrace_filter.filter(["a\xE9"]) }

    assert_equal(["a�"], recording.seen)
  ensure
    Minitest.backtrace_filter = original
  end
end
