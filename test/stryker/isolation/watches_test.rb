# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require_relative("../../support/watch_stand_ins")
require "stryker/isolation/watches"

# How one thread watches many processes: their pipes, their lines, their
# ends, and their time limits. Time is the test's own: a clock that moves only
# when the test moves it, and stand-ins for the processes and their pipes, so
# no test waits on the wall clock. [WatchesProcessesTest] runs real processes.
class WatchesTest < Minitest::Test
  include IsolationStandIns
  include WatchStandIns

  parallelize_me!

  # The line a run's process writes as its first test starts, which starts
  # the run's time limit.
  STARTED = %({"started":{}}\n)
  private_constant(:STARTED)

  # Watches of processes that the test scripts, on the test's clock.
  def watching(processes, timeout_ms: 30_000)
    Stryker::Isolation::Watches.new.tap do |set|
      processes.each { |subject, made| set.add(watch(subject, made, timeout_ms)) }
    end
  end

  # Watches of processes whose first test has started, each with the time
  # limit that +timeouts+ gives its subject.
  def started(timeouts)
    processes = timeouts.to_h { |subject, _| [subject, scripted_process] }
    set = Stryker::Isolation::Watches.new
    timeouts.each { |subject, timeout_ms| set.add(watch(subject, processes[subject], timeout_ms)) }
    processes.each_value { |made| made.write(STARTED) }
    waited(set)
    [set, processes]
  end

  def watch(subject, made, timeout_ms)
    timer = Stryker::Isolation::Timer.new(timeout_ms, clock:)
    Stryker::Isolation::Watch.new(subject, made, made.reader, timer)
  end

  # One wait of +set+, and the lines it read and the subjects that ended.
  def waited(set)
    lines = Hash.new { |hash, key| hash[key] = [] }
    _, ended = set.wait([]) { |subject, line| lines[subject] << line }
    [lines, ended.to_h]
  end

  def test_each_line_comes_with_its_subject
    first = scripted_process
    second = scripted_process
    set = watching({ first:, second: })
    # A line arrives in pieces, so the start of one waits for its end.
    first.write("one\ntw")
    second.write("three\n")
    lines, = waited(set)
    first.write("o\n")
    rest, = waited(set)

    assert_equal({ first: %W[one\n two\n], second: ["three\n"] }, lines.merge(rest) { |_, was, now| was + now })
  end

  def test_a_process_past_its_time_is_timed_out
    set, processes = started(slow: 300)
    clock.advance(0.3)
    ending = waited(set).last[:slow]

    assert_equal([true, 300.0, [0.0]], [ending.timed_out, ending.duration_ms.round(3), processes[:slow].waits])
  end

  def test_a_process_inside_its_time_is_not_ended
    set, = started(slow: 300)
    clock.advance(0.299)

    assert_empty(waited(set).last)
  end

  def test_the_process_whose_time_ends_first_ends_first
    set, = started(short: 300, long: 3000)
    clock.advance(0.3)
    began = Stryker::Isolation::Timer.now
    _, ended = waited(set)

    # The wait lasts until the first time limit, not the last, so a process
    # past its limit isn't left running until the others are past theirs. A
    # wait until the last limit takes 3 seconds of the real clock, which a
    # wait that returns at once never comes near.
    assert_equal([[:short], true], [ended.keys, Stryker::Isolation::Timer.now - began < 1.5])
  end

  def test_a_process_whose_pipe_another_holds_ends_without_timing_out
    # The pipe stays open until the time limit ends.
    parent = scripted_process
    set = watching({ parent: }, timeout_ms: 300)
    parent.write("#{STARTED}done\n")
    parent.finish(holding: true)
    lines, = waited(set)
    clock.advance(0.3)
    ending = waited(set).last[:parent]

    assert_equal([[STARTED, "done\n"], 0, false], [lines[:parent], ending.exit_status, ending.timed_out])
  end

  def test_a_time_limit_starts_with_the_first_test
    # The limit is shorter than the wait before the first test, as a
    # process's start can be (#85).
    late = scripted_process
    set = watching({ late: }, timeout_ms: 300)
    clock.advance(5.0)
    late.write(STARTED)

    assert_empty(waited(set).last)
    late.finish
    _, endings = waited(set)

    assert_equal([0, false], [endings[:late].exit_status, endings[:late].timed_out])
  end

  def test_an_input_that_can_be_read_comes_back
    reader, writer = IO.pipe
    writer.write("run\n")

    assert_equal([[reader], []], Stryker::Isolation::Watches.new.wait([reader]) { nil })
  ensure
    [reader, writer].each { |io| io&.close }
  end
end
