# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "stryker/isolation/watches"

# How one thread watches many processes: their pipes, their lines, their
# ends, and their time limits. The processes are real Ruby processes that
# write scripted lines, on every system.
class WatchesTest < Minitest::Test
  include IsolationStandIns

  parallelize_me!

  def watches(scripts, timeout_ms: 30_000)
    Stryker::Isolation::Watches.new.tap do |set|
      scripts.each do |subject, script|
        pid, reader = scripted("$stdout.sync = true; #{script}")
        timer = Stryker::Isolation::Timer.new(timeout_ms)
        set.add(Stryker::Isolation::Watch.new(subject, Stryker::Isolation::Child.new(pid), reader, timer))
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

  def test_each_line_comes_with_its_subject
    lines, = watched(watches({ first: "puts 'one'; print 'two'; sleep 0.2; puts", second: "puts 'three'" }), 2)

    assert_equal({ first: %W[one\n two\n], second: ["three\n"] }, lines)
  end

  def test_each_end_comes_with_its_ending
    _, endings = watched(watches({ first: "exit!(0)", second: "exit!(3)" }), 2)

    assert_equal(
      { first: [0, false], second: [3, false] },
      endings.transform_values do |ending|
        [ending.exit_status, ending.timed_out]
      end
    )
  end

  def test_a_process_past_its_time_is_killed_and_timed_out
    lines, endings = watched(watches({ slow: "puts 'before'; sleep" }, timeout_ms: 3000))
    ending = endings[:slow]

    assert_equal([["before\n"], true], [lines[:slow], ending.timed_out])
    assert_operator(ending.duration_ms, :>=, 3000)
  end

  def test_a_process_whose_pipe_another_holds_ends_without_timing_out
    # The grandchild inherits the pipe and outlives the process.
    script = "Process.spawn(RbConfig.ruby, '-e', 'sleep 8'); puts 'done'; exit!(0)"
    lines, endings = watched(watches({ parent: script }, timeout_ms: 5000))

    assert_equal([["done\n"], 0, false], [lines[:parent], endings[:parent].exit_status, endings[:parent].timed_out])
  end

  def test_an_input_that_can_be_read_comes_back
    reader, writer = IO.pipe
    writer.write("run\n")

    assert_equal([[reader], []], Stryker::Isolation::Watches.new.wait([reader]) { nil })
  ensure
    [reader, writer].each { |io| io&.close }
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
