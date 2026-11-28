# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/isolation/cleanup"

# What a cleanup does when a step of it raises: the steps after it still run,
# and the first error reaches the caller, except a signal, which ends the
# cleanup at once.
class CleanupTest < Minitest::Test
  def test_every_step_runs_and_a_cleanup_without_errors_returns_nil
    steps = []

    assert_nil(Stryker::Isolation::Cleanup.run(-> { steps << 0 }, -> { steps << 1 }))
    assert_equal([0, 1], steps)
  end

  def test_a_step_after_one_that_raised_still_runs_and_the_first_error_reaches_the_caller
    steps = []
    error = assert_raises(ThreadError) do
      Stryker::Isolation::Cleanup.run(
        -> { raise(ThreadError, "first") }, -> { steps << :second }, -> { raise(IOError, "third") }
      )
    end

    assert_equal(["first", %i[second]], [error.message, steps])
  end

  def test_a_signal_in_a_step_ends_the_cleanup_at_once
    steps = []

    assert_raises(Interrupt) { Stryker::Isolation::Cleanup.run(-> { raise(Interrupt) }, -> { steps << :second }) }
    assert_empty(steps)
  end
end
