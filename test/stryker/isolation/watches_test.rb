# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "stryker/isolation/watches"
require "tmpdir"

# How one thread watches many processes: their pipes, their lines, their
# ends, and their time limits. The processes are real Ruby processes that
# write scripted lines, on every system.
class WatchesTest < Minitest::Test
  include IsolationStandIns

  parallelize_me!

  # The line a run's process writes as its first test starts, which starts
  # the run's time limit.
  STARTED = %q(puts('{"started":{}}'))
  private_constant(:STARTED)

  # Each time limit starts once its process has written a line or ended, so
  # how long Ruby takes to start never counts against the limit. With +ended+,
  # it starts once the process has ended, and a pipe that another process
  # holds open is what keeps the watch going.
  def watches(scripts, timeout_ms: 30_000, ended: false)
    Stryker::Isolation::Watches.new.tap do |set|
      scripts.each do |subject, script|
        pid, reader = scripted("$stdout.sync = true; #{script}")
        child = Stryker::Isolation::Child.new(pid)
        # No timeout here: a script that writes nothing and never ends keeps
        # the test waiting.
        reader.wait_readable
        child.end_within(60) if ended
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
    lines, endings = watched(watches({ slow: "#{STARTED}; sleep" }, timeout_ms: 300))
    ending = endings[:slow]

    assert_equal([[%({"started":{}}\n)], true], [lines[:slow], ending.timed_out])
    assert_operator(ending.duration_ms, :>=, 300)
  end

  # A script that starts a grandchild, which inherits the pipe and outlives
  # the process, and records the grandchild's process ID in +record+, so that
  # the test can end it.
  def script_with_grandchild(record)
    grandchild = "Process.spawn(RbConfig.ruby, '-e', 'sleep 8')"
    "#{STARTED}; File.write(#{record.dump}, #{grandchild}.to_s); puts 'done'; exit!(0)"
  end

  def test_a_process_whose_pipe_another_holds_ends_without_timing_out
    # The pipe stays open until the time limit ends.
    Dir.mktmpdir do |folder|
      record = File.join(folder, "grandchild")
      lines, endings = watched(watches({ parent: script_with_grandchild(record) }, timeout_ms: 300, ended: true))

      assert_equal(
        [[%({"started":{}}\n), "done\n"], 0, false],
        [lines[:parent], endings[:parent].exit_status, endings[:parent].timed_out]
      )
    ensure
      end_process(Integer(File.read(record), 10)) if record && File.exist?(record)
    end
  end

  def test_a_time_limit_starts_with_the_first_test
    # The limit is shorter than the wait before the first test, as a
    # process's start can be (#85).
    pid, reader = scripted("$stdout.sync = true; sleep 0.6; #{STARTED}; exit!(0)")
    watch = Stryker::Isolation::Watch.new(:late, Stryker::Isolation::Child.new(pid), reader, Stryker::Isolation::Timer.new(300))
    set = Stryker::Isolation::Watches.new
    set.add(watch)
    _, endings = watched(set)

    assert_equal([0, false], [endings[:late].exit_status, endings[:late].timed_out])
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
