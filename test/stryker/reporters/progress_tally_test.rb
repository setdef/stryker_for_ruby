# frozen_string_literal: true

require_relative("../../support/progress_run")
require "stryker/reporters/progress_tally"

# Checks what the progress reporters count: the mutants that the run tests,
# their statuses, how much of the work is done, and the time left that
# StrykerJS estimates from it.
class ProgressTallyTest < Minitest::Test
  def tally(weights = { 1 => 30.0, 2 => 10.0 })
    Stryker::Reporters::ProgressTally.new(weights)
  end

  def record(tally, id, status)
    tally.record(ProgressRun.tested(id, status).result)
  end

  def test_counts_the_tested_mutants_and_those_that_survived_or_timed_out
    counted = tally({ 1 => 1.0, 2 => 1.0, 3 => 1.0, 4 => 1.0 })
    %w[Survived Timeout Killed Survived].each_with_index { |status, index| record(counted, index + 1, status) }

    assert_equal([4, 4, 2, 1], [counted.mutants, counted.tested, counted.survived, counted.timed_out])
  end

  def test_counts_nothing_for_a_mutant_that_the_run_does_not_test
    counted = tally

    assert_equal([nil, 0, 0.0], [record(counted, 9, "Survived"), counted.tested, counted.fraction])
  end

  def test_the_work_done_is_the_weight_of_the_tested_mutants_over_all_the_weights
    counted = tally
    record(counted, 1, "Killed")

    assert_in_delta(0.75, counted.fraction)
  end

  def test_every_mutant_weighs_the_same_when_every_weight_is_zero
    counted = tally({ 1 => 0.0, 2 => 0.0 })
    record(counted, 1, "Killed")

    assert_in_delta(0.5, counted.fraction)
  end

  def test_the_work_is_all_done_when_every_mutant_is_tested_whatever_the_order_of_the_sums
    weights = { 1 => 0.1, 2 => 0.2, 3 => 0.3 }
    counted = tally(weights)
    [3, 1, 2].each { |id| record(counted, id, "Killed") }

    assert_in_delta(1.0, counted.fraction)
  end

  def test_estimates_the_time_left_from_the_time_per_weight_so_far
    counted = tally
    record(counted, 1, "Killed")

    assert_equal(20, counted.seconds_left(60.9))
  end

  def test_gives_the_whole_percent_and_the_times
    counted = tally
    record(counted, 1, "Killed")

    assert_equal([75, "elapsed: ~1m, remaining: <1m"], [counted.percent, counted.times(61.0)])
  end

  def test_has_no_estimate_before_any_work_is_done
    assert_nil(tally.seconds_left(60.0))
  end

  def test_has_no_estimate_when_no_work_is_left
    counted = tally
    record(counted, 1, "Killed")
    record(counted, 2, "Killed")

    assert_nil(counted.seconds_left(60.0))
  end

  def test_has_no_estimate_when_the_time_left_rounds_down_to_less_than_a_second
    counted = tally
    record(counted, 1, "Killed")

    assert_nil(counted.seconds_left(2.0))
    assert_equal("elapsed: <1m, remaining: n/a", counted.times(2.0))
  end
end
