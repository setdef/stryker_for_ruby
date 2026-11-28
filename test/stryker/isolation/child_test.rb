# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "delegate"
require "stryker/isolation/child"

# How the orchestrator, or the fork parent, holds a process it started:
# its waiter reaps it, and nothing kills the process itself once it has ended.
class ChildTest < Minitest::Test
  include IsolationStandIns

  def test_a_process_that_has_ended_is_stopped
    child = Stryker::Isolation::Child.new(ended_pid_unreaped)
    child.end_within(20)

    assert_nil(child.stop)
    assert_predicate(child, :ended?)
  end

  def test_a_process_still_running_is_killed_when_stopped
    pid, reader = scripted("sleep")
    child = Stryker::Isolation::Child.new(pid)

    assert_nil(child.stop)
    assert_predicate(child, :ended?)
  ensure
    reader&.close
  end

  def test_a_process_still_running_at_the_end_of_its_wait_has_ended_when_the_wait_returns
    pid, reader = scripted("sleep")
    child = Stryker::Isolation::Child.new(pid)

    assert_equal([true, true], [child.end_within(0), child.ended?])
  ensure
    reader&.close
  end

  # A process whose waiter a signal interrupts in its first wait, as one
  # does that Ctrl-C reaches while it waits: the waiter raises Interrupt
  # once, and then waits as the real one does.
  class InterruptedProcess
    class Waiter < SimpleDelegator
      def join(*)
        ::Kernel.raise(Interrupt) unless @interrupted

        super
      ensure
        @interrupted = true
      end
    end
    private_constant(:Waiter)

    def detach(pid)
      Waiter.new(Process.detach(pid))
    end

    def kill(*)
      Process.kill(*)
    end
  end
  private_constant(:InterruptedProcess)

  def test_a_signal_during_the_wait_ends_the_process_before_it_reaches_the_caller
    pid, reader = scripted("sleep")
    child = Stryker::Isolation::Child.new(pid, InterruptedProcess.new)

    assert_raises(Interrupt) { child.end_within(60) }
    assert_predicate(child, :ended?)
  ensure
    reader&.close
  end
end
