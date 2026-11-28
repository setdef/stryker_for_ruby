# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "stryker/isolation/child_process"
require "stryker/isolation/process_group"

# How the orchestrator holds a process it started and reaps itself, with no
# thread: it asks without waiting whether the process still runs, ends it
# when told to, and never kills the process itself once it has been reaped.
class ChildProcessTest < Minitest::Test
  include IsolationStandIns

  def kills
    return [[:kill, :KILL, -FakeProcess::PID]] if Stryker::Isolation::ProcessGroup::SYSTEM.groups?

    []
  end

  def test_a_process_that_runs_is_running_until_it_is_ended_and_then_reaped
    pid, reader = scripted("sleep")
    child = Stryker::Isolation::ChildProcess.new(pid)
    running = child.running?
    child.end_now

    assert_equal([true, false, true], [running, child.running?, child.reaped?])
    assert_raises(Errno::ECHILD) { Process.wait(pid) }
  ensure
    reader&.close
  end

  def test_a_process_that_ended_is_reaped_and_left_alone_by_end_now
    process = FakeProcess.new
    child = Stryker::Isolation::ChildProcess.new(FakeProcess::PID, process)
    child.end_now

    assert_equal([[[:wait2, FakeProcess::PID, Process::WNOHANG]], 0], [process.calls, child.status.exitstatus])
  end

  def test_stopping_a_process_that_ended_kills_only_what_it_left_in_its_group
    process = FakeProcess.new
    Stryker::Isolation::ChildProcess.new(FakeProcess::PID, process).stop

    assert_equal([[:wait2, FakeProcess::PID, Process::WNOHANG], *kills], process.calls)
  end

  def test_stopping_a_process_that_runs_kills_it_and_reaps_it
    pid, reader = scripted("sleep")
    child = Stryker::Isolation::ChildProcess.new(pid)

    assert_nil(child.stop)
    assert_predicate(child, :reaped?)
    assert_raises(Errno::ECHILD) { Process.wait(pid) }
  ensure
    reader&.close
  end

  def test_the_status_of_a_process_not_yet_reaped_waits_until_it_ends
    pid, reader = scripted("exit!(3)")
    child = Stryker::Isolation::ChildProcess.new(pid)

    assert_equal([3, true], [child.status.exitstatus, child.reaped?])
  ensure
    reader&.close
  end

  # A process that the system lets be reaped only from its +ends_at+'th
  # ask on, as an ending process can be for a moment after its pipe ended.
  class Ending < FakeProcess
    def initialize(ends_at)
      super()
      @asks = 0
      @ends_at = ends_at
    end

    def wait2(pid, *flags)
      @asks += 1
      super if @asks >= @ends_at
    end
  end
  private_constant(:Ending)

  def test_a_reap_with_a_moment_asks_again_until_the_process_can_be_reaped
    child = Stryker::Isolation::ChildProcess.new(FakeProcess::PID, Ending.new(3))
    child.reap(30)

    assert_predicate(child, :reaped?)
  end

  def test_a_reap_with_a_moment_gives_up_when_the_moment_is_over
    child = Stryker::Isolation::ChildProcess.new(FakeProcess::PID, Ending.new(Float::INFINITY))
    child.reap(0.001)

    refute_predicate(child, :reaped?)
  end

  def test_a_reap_without_a_moment_asks_once
    process = Ending.new(2)
    child = Stryker::Isolation::ChildProcess.new(FakeProcess::PID, process)
    child.reap

    assert_equal([false, []], [child.reaped?, process.calls])
  end
end
