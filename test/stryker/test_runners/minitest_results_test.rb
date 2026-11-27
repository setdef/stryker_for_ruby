# frozen_string_literal: true

require_relative("../../support/minitest_project")
require "minitest/mock"

# How the Minitest adapter runs a test and turns what Minitest recorded into
# its result, with small projects loaded into this process. Each project's
# classes have names of their own, because every class stays defined here.
class MinitestResultsTest < Minitest::Test
  include MinitestProject

  TEARDOWN = { "test/teardown_test.rb": <<~RUBY }.freeze
    class TeardownRaisesTest < Minitest::Test
      def teardown = raise("Raised in teardown.")
      def test_passes = assert(true)
    end
  RUBY
  SKIP_THEN_TEARDOWN = { "test/skip_teardown_test.rb": <<~RUBY }.freeze
    class SkipThenTeardownTest < Minitest::Test
      def teardown = raise("Raised in teardown.")
      def test_skips = skip
    end
  RUBY
  ABSTRACT = { "test/abstract_test.rb": <<~RUBY }.freeze
    class AbstractSharedTest < Minitest::Test
      abstract_test_case!
      def test_shared = flunk("Minitest runs this only in a subclass.")
    end

    class ConcreteSharedTest < AbstractSharedTest
      def test_shared = assert(true)
    end
  RUBY
  BROKEN_HOOK = { "test/broken_hook_test.rb": <<~RUBY }.freeze
    require "minitest/hooks/test"

    class BeforeAllRaisesTest < Minitest::Test
      include Minitest::Hooks

      def before_all = raise("Raised in before_all.")
      def test_never = flunk("Minitest runs no test after its before_all hook raises.")
    end
  RUBY
  SKIPPING_HOOK = { "test/skipping_hook_test.rb": <<~RUBY }.freeze
    require "minitest/hooks/test"

    class SkipsInAfterAllTest < Minitest::Test
      include Minitest::Hooks

      def after_all = skip
      def test_passes = assert(true)
    end
  RUBY
  TWO_FAILURES = { "test/two_failures_test.rb": <<~RUBY }.freeze
    require "minitest/hooks/test"

    class FailsTwiceTest < Minitest::Test
      include Minitest::Hooks

      def after_all = raise("Raised in after_all.")
      def test_fails = flunk("Failed in the test.")
    end
  RUBY
  TIMED = { "test/timed_test.rb": "class TimedTest < Minitest::Test; def test_t = pass; end\n" }.freeze
  private_constant(:ABSTRACT, :BROKEN_HOOK, :SKIP_THEN_TEARDOWN, :SKIPPING_HOOK)
  private_constant(:TEARDOWN, :TIMED, :TWO_FAILURES)

  def test_a_test_that_passes_and_then_raises_in_teardown_fails
    result = run_ids(loaded(TEARDOWN), "TeardownRaisesTest#test_passes").first

    assert_equal("failed", result.status)
    assert_includes(result.failure_message, "Raised in teardown.")
  end

  def test_a_test_that_skips_and_then_raises_in_teardown_is_skipped_as_minitest_counts_it
    assert_equal("skipped", run_ids(loaded(SKIP_THEN_TEARDOWN), "SkipThenTeardownTest#test_skips").first.status)
  end

  def test_a_test_whose_before_all_hook_raises_fails_with_the_hooks_error
    result = run_ids(loaded(BROKEN_HOOK), "BeforeAllRaisesTest#test_never").first

    assert_equal("failed", result.status)
    assert_includes(result.failure_message, "Raised in before_all.")
    refute_includes(result.failure_message, "Minitest runs no test")
  end

  def test_a_test_that_passes_is_passed_when_a_hook_around_the_class_skips
    result = run_ids(loaded(SKIPPING_HOOK), "SkipsInAfterAllTest#test_passes").first

    assert_equal(["passed", nil], [result.status, result.failure_message])
  end

  def test_the_message_of_a_failed_test_holds_each_failure_that_minitest_recorded
    result = run_ids(loaded(TWO_FAILURES), "FailsTwiceTest#test_fails").first

    assert_includes(result.failure_message, "Failed in the test.")
    assert_includes(result.failure_message, "Raised in after_all.")
  end

  def test_a_test_of_an_abstract_test_case_that_minitest_never_runs_is_skipped
    results = run_ids(loaded(ABSTRACT), "AbstractSharedTest#test_shared", "ConcreteSharedTest#test_shared")

    assert_equal([["skipped", nil], ["passed", nil]], results.map { |result| [result.status, result.failure_message] })
  end

  def test_the_time_is_the_monotonic_clocks_in_milliseconds
    runner = loaded(TIMED)
    times = [1000.0, 1250.5]
    clock = Process.method(:clock_gettime)
    stand_in = lambda do |id, *unit|
      (unit == [:float_millisecond] && id == Process::CLOCK_MONOTONIC) ? times.shift : clock.call(id, *unit)
    end
    result = Process.stub(:clock_gettime, stand_in) { run_ids(runner, "TimedTest#test_t").first }

    assert_in_delta(250.5, result.duration_ms)
  end

  def test_the_reporter_tells_minitests_info_handler_that_the_run_passed
    assert_predicate(Stryker::TestRunners::MinitestRunner::Outcome.new("test_x"), :passed?)
  end
end
