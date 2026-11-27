# frozen_string_literal: true

require_relative("../support/sample_plan")
require_relative("../test_helper")

# Checks that each run's time limit is StrykerJS's: timeoutFactor times the
# dry-run time of the run's tests, plus timeoutMS, plus the dry run's
# overhead, rounded up to a whole millisecond.
class PlanTimeLimitTest < Minitest::Test
  include SamplePlan

  def test_a_runtime_limit_is_the_tests_time_times_the_factor_plus_timeout_ms_plus_the_overhead
    # 1.5 x (100 + 20) + 5000 + (200 - 100 - 30 - 20)
    assert_equal(5230, plan_of([mutant(3)]).runs.first.timeout_ms)
  end

  def test_a_runtime_limit_counts_only_the_tests_that_reached_the_mutant
    # 1.5 x 100 + 5000 + 50
    assert_equal(5200, plan_of([mutant(6)]).runs.first.timeout_ms)
  end

  def test_a_static_limit_counts_every_test_that_runs
    # 1.5 x 120 + 5000 + 50, though only test_bulk reached it
    assert_equal(5230, plan_of([mutant(5)]).runs.first.timeout_ms)
  end

  def test_a_limit_rounds_up_to_a_whole_millisecond
    config = Stryker::Config.new(mutate: [], test_runner: "minitest", timeout_ms: 2500.25, timeout_factor: 2.0)

    # 2 x 120 + 2500.25 + 50
    assert_equal(2791, plan_of([mutant(3)], dry_run, config).runs.first.timeout_ms)
  end

  def test_a_dry_run_shorter_than_its_tests_adds_no_overhead
    run = plan_of([mutant(3)], dry_run(duration_ms: 10.0)).runs.first

    assert_equal(5180, run.timeout_ms)
  end
end
