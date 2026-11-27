# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/isolation/parent_process"
require "stryker/isolation/timer"

# How a run's timer counts: a fixed limit for its process to start and load,
# and then the run's time limit, from the start of its first test.
class TimerTest < Minitest::Test
  def test_before_its_first_test_a_run_has_the_limit_for_starting
    timer = Stryker::Isolation::Timer.new(500)

    assert_in_delta(Stryker::Isolation::Timer::START_SECONDS, timer.left, 5.0)
    refute_predicate(timer, :testing?)
  end

  def test_from_its_first_test_a_run_has_its_own_limit
    timer = Stryker::Isolation::Timer.new(60_000, 0)
    timer.tests_started

    assert_in_delta(60.0, timer.left, 5.0)
    assert_predicate(timer, :testing?)
  end

  def test_a_later_test_starts_no_new_limit
    timer = Stryker::Isolation::Timer.new(50, 0)
    timer.tests_started
    # Past the limit of the first test, so a second start that set a new
    # limit would leave time.
    sleep(0.06)
    timer.tests_started

    assert_in_delta(0.0, timer.left)
  end

  def test_a_timer_past_its_deadline_has_no_time_left
    assert_in_delta(0.0, Stryker::Isolation::Timer.new(60_000, 0).left)
  end

  def test_the_elapsed_time_counts_from_the_start_of_the_process
    assert_operator(Stryker::Isolation::Timer.new(60_000).elapsed_ms, :>=, 0)
  end

  def test_the_limit_for_starting_is_the_fork_parents_limit_for_loading
    assert_equal(Stryker::Isolation::ParentProcess::LOAD_SECONDS, Stryker::Isolation::Timer::START_SECONDS)
  end
end
