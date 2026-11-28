# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "stryker/isolation/watches"

# How one thread watches many processes, against real ones: real Ruby
# processes that write scripted lines, on every system, so that the watch is
# proven on a real pipe, a real exit status, a real KILL, and the real clock.
# The margins are the ones a real bug alone crosses: a process that is to end
# by its own exit has 30 seconds, and a process that is to be killed runs for
# good. WatchesTest holds every other check of the watches, on a clock that
# the test moves.
class WatchesProcessesTest < Minitest::Test
  include IsolationStandIns

  parallelize_me!

  # The line a run's process writes as its first test starts, which starts
  # the run's time limit.
  STARTED = %({"started":{}}\n)
  private_constant(:STARTED)

  # Watches of real processes that run +scripts+, on the real clock. Each
  # time limit starts once its process has written a line, so how long Ruby
  # takes to start never counts against it.
  def watches(scripts, timeout_ms: 30_000)
    Stryker::Isolation::Watches.new.tap do |set|
      scripts.each do |subject, script|
        pid, reader = scripted("$stdout.sync = true; #{script}")
        child = Stryker::Isolation::Child.new(pid)
        # No timeout here: a script that writes nothing and never ends keeps
        # the test waiting.
        reader.wait_readable
        timer = Stryker::Isolation::Timer.new(timeout_ms)
        set.add(Stryker::Isolation::Watch.new(subject, child, reader, timer))
      end
    end
  end

  # Waits until +count+ watches of +set+ end, and returns each subject's
  # lines and ending.
  def watched(set, count = 1)
    lines = Hash.new { |hash, key| hash[key] = [] }
    endings = {}
    until endings.size == count
      _, ended = set.wait([]) { |subject, line| lines[subject] << line }
      endings.merge!(ended.to_h)
    end
    [lines, endings]
  end

  def test_each_end_comes_with_its_ending
    # Real processes, so that the watch reads real pipes and real exit
    # statuses.
    _, endings = watched(watches({ first: "exit!(0)", second: "exit!(3)" }), 2)

    assert_equal(
      { first: [0, false], second: [3, false] },
      endings.transform_values do |ending|
        [ending.exit_status, ending.timed_out]
      end
    )
  end

  def test_a_process_past_its_time_is_killed_and_timed_out
    # A real process that writes its first test's line and then runs for
    # good, on the real clock: nothing but the watch ends it, so this test
    # fails only when the watch fails to end it at its limit.
    lines, endings = watched(watches({ slow: "print #{STARTED.dump}; sleep" }, timeout_ms: 100))
    ending = endings[:slow]

    assert_equal([[STARTED], true], [lines[:slow], ending.timed_out])
    assert_operator(ending.duration_ms, :>=, 100)
  end

  def test_stop_ends_every_process_still_running
    pid, reader = scripted("sleep")
    watch = Stryker::Isolation::Watch.new(:sleeper, Stryker::Isolation::Child.new(pid), reader, Stryker::Isolation::Timer.new(30_000))
    set = Stryker::Isolation::Watches.new
    set.add(watch)
    set.stop

    assert_predicate(watch.output, :closed?)
  end
end
