# frozen_string_literal: true

require_relative("../../support/project_side_stand_ins")
require "stryker/runtime/dry_run_tests"
require "stryker/testing/observer"

# The tests of a dry run, with a stand-in test runner and loader, so they run
# in this process: every test once, through the dry run's observer, and then
# the loading check.
class DryRunTestsTest < Minitest::Test
  include ProjectSideStandIns

  def run_tests(loader)
    runner = Runner.new
    found = Stryker::Runtime::DryRunTests.new(runner, %w[A#test_a B#test_b], Stryker::Runtime::Recorder.new, loader)
      .call(Stryker::Testing::Observer.new)
    [runner, found]
  end

  def test_the_dry_run_runs_every_test_stopping_at_a_failure_and_then_checks_the_loading
    loader = Loader.new
    runner, found = run_tests(loader)

    assert_equal([[:run, %w[A#test_a B#test_b], true]], runner.calls)
    assert_equal(%w[A#test_a B#test_b], found.results.map { |result| result.test.id })
    assert_equal([[[], []], true], [found.buckets.values_at("A#test_a", "B#test_b"), loader.checked])
  end

  def test_a_failed_loading_check_is_the_dry_runs_error
    error = Stryker::Runtime::LoadingError.new(["/app/lib/invoice.rb"], nil)

    assert_same(error, assert_raises(Stryker::Runtime::LoadingError) { run_tests(Loader.new(error)) })
  end
end
