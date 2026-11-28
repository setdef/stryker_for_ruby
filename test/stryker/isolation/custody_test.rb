# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "stryker/isolation/custody"
require "stryker/isolation/deferred"

# What a custody leaves to its caller: the mask over signals, which both of
# its callers hold already, and which one custody alone would not make whole.
class CustodyTest < Minitest::Test
  include IsolationStandIns

  # What a launch made, noting that it was removed.
  class Made
    attr_reader :removed

    def remove
      @removed = true
    end
  end
  private_constant(:Made)

  def test_a_signal_in_the_block_reaches_it_at_once_and_the_custody_removes_what_the_launch_made
    made = Made.new
    steps = []

    assert_raises(Interrupt) do
      Stryker::Isolation::Custody.new(made).around do
        Thread.current.raise(Interrupt)
        steps << :after_the_signal
      end
    end
    assert_equal([[], true], [steps, made.removed])
  end

  def test_a_signal_in_the_block_waits_when_the_caller_defers_signals
    steps = []

    assert_raises(Interrupt) do
      Stryker::Isolation::Deferred.signals do
        Stryker::Isolation::Custody.new(Made.new).around do
          Thread.current.raise(Interrupt)
          steps << :after_the_signal
        end
      end
    end
    assert_equal(%i[after_the_signal], steps)
  end

  def test_a_block_that_raises_after_taking_a_child_ends_its_process_and_removes_what_the_launch_made
    pid, reader = scripted("sleep")
    made = Made.new
    holding = -> (custody) { custody.child(pid).then { raise(ThreadError) } }

    assert_raises(ThreadError) { Stryker::Isolation::Custody.new(made).around(&holding) }
    assert_equal([true, true], [made.removed, ended?(pid)])
  ensure
    reader&.close
  end

  # Whether the process has ended and been reaped, without waiting for it.
  def ended?(pid)
    Process.wait(pid, Process::WNOHANG)
    false
  rescue Errno::ECHILD
    true
  end
end
