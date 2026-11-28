# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "stryker/isolation/fresh_run"
require "stryker/isolation/messages"
require "stryker/isolation/watch"

# What the orchestrator and the fork parent do with a process that has ended:
# they end what it left running in its group, and the parent takes the lines
# still in its pipe. A stand-in for Process records the kills, so the tests
# run the same on every system.
class LeftoversTest < Minitest::Test
  include IsolationStandIns

  Status = Struct.new(:termsig, :exitstatus)
  private_constant(:Status)

  # A Process stand-in whose process ended with status 0.
  class EndedProcess < IsolationStandIns::FakeProcess
    class Done < IsolationStandIns::Waiter
      def value
        Status.new(nil, 0)
      end
    end

    def detach(pid)
      @calls << [:detach, pid]
      Done.new
    end
  end
  private_constant(:EndedProcess)

  # What a run's folder is to a fresh process, when the process wrote
  # nothing.
  class Folder
    def messages
      Stryker::Isolation::Messages.new([])
    end

    def errors
      ""
    end

    def remove
      nil
    end
  end
  private_constant(:Folder)

  def kills
    return [[:kill, :KILL, -FakeProcess::PID]] if Stryker::Isolation::ProcessGroup::SYSTEM.groups?

    []
  end

  def test_a_watch_ends_what_its_ended_process_left_in_its_group
    process = EndedProcess.new
    reader, writer = IO.pipe
    writer.close
    child = Stryker::Isolation::Child.new(FakeProcess::PID, process)
    Stryker::Isolation::Watch.new(:one, child, reader, Stryker::Isolation::Timer.new(30_000)).finish { nil }

    assert_equal([[:detach, FakeProcess::PID], *kills], process.calls)
  end

  def test_a_watch_takes_the_lines_still_in_the_pipe_when_its_process_has_ended
    reader, writer = IO.pipe
    writer.write("last\n")
    writer.close
    child = Stryker::Isolation::Child.new(FakeProcess::PID, EndedProcess.new)
    lines = []
    Stryker::Isolation::Watch.new(:one, child, reader, Stryker::Isolation::Timer.new(30_000)).finish { |_, line| lines << line }

    assert_equal(["last\n"], lines)
  end

  def test_stopping_a_child_that_has_ended_ends_what_it_left_running_in_its_group
    # Only its group: once a process has ended, its ID may belong to another
    # process, and Windows has no groups.
    process = EndedProcess.new
    Stryker::Isolation::Child.new(FakeProcess::PID, process).stop

    assert_equal([[:detach, FakeProcess::PID], *kills], process.calls)
  end

  def test_stopping_a_fresh_run_whose_process_has_ended_ends_what_it_left_running_in_its_group
    process = EndedProcess.new
    child = Stryker::Isolation::Child.new(FakeProcess::PID, process)
    running_fresh(Folder.new, child, Stryker::Isolation::Timer.new(30_000)).stop

    assert_equal([[:detach, FakeProcess::PID], *kills], process.calls)
  end

  def test_a_fresh_run_ends_what_its_ended_process_left_in_its_group
    process = EndedProcess.new
    child = Stryker::Isolation::Child.new(FakeProcess::PID, process)
    endings = []
    fresh = running_fresh(Folder.new, child, Stryker::Isolation::Timer.new(30_000)) { |_, ending| endings << ending }
    fresh.finish

    assert_equal([[0], [[:detach, FakeProcess::PID], *kills]], [endings.map(&:exit_status), process.calls])
  end
end
