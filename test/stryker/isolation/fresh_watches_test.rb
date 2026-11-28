# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "stryker/isolation/child_process"
require "stryker/isolation/fresh_folder"
require "stryker/isolation/fresh_run"
require "stryker/isolation/fresh_run/running"
require "stryker/isolation/fresh_watches"
require "stryker/isolation/messages"
require "stryker/isolation/output_pipe"
require "stryker/isolation/timer"

# Which fresh runs the set finishes: each whose process has been reaped or
# has run out of time, after one wait for every run, until a pipe is ready or
# the soonest run needs a look. The first tests use stand-ins for the runs and
# for `IO.select`; the last use the real wait.
class FreshWatchesTest < Minitest::Test
  include IsolationStandIns

  # A run that is done when +done+ says so, or after a wait when +ends+
  # says so, that needs a look within +wake_in+ seconds, and whose pipe is
  # +output+. It notes what each take found ready.
  class Watch
    attr_reader :name, :output, :wake_in, :taken

    def initialize(name, done: false, wake_in: 5.0, output: nil, ends: false)
      @name = name
      @done = done
      @wake_in = wake_in
      @output = output
      @ends = ends
      @taken = []
    end

    def take(ready)
      @taken << ready
      @done = true if @ends
    end

    def done?
      @done
    end

    def finish
      @finished << name
      nil
    end

    def finished_into(list)
      @finished = list
      self
    end
  end
  private_constant(:Watch)

  # `IO`'s select, which returns at once with what +ready+ holds, and notes
  # the pipes and the timeout of each wait.
  class Select
    attr_reader :waits

    def initialize(ready = [])
      @ready = ready
      @waits = []
    end

    def select(readers, _writers, _errors, timeout)
      @waits << [readers, timeout]
      [@ready, [], []] if @ready.any?
    end
  end
  private_constant(:Select)

  def finished(*watches, io: Select.new)
    set = Stryker::Isolation::FreshWatches.new(io)
    names = []
    watches.each { |watch| set.add(watch.finished_into(names)) }
    set.finish
    [names, set.size]
  end

  def test_each_run_that_is_done_after_the_wait_is_finished_and_no_other
    assert_equal([[:done], 1], finished(Watch.new(:running), Watch.new(:done, done: true)))
  end

  def test_the_wait_is_for_every_open_pipe_until_the_soonest_run_needs_a_look
    pipe = IO.pipe.first
    io = Select.new
    finished(Watch.new(:later, wake_in: 9.0, output: pipe), Watch.new(:soon, wake_in: 1.0), io:)

    assert_equal([[[pipe], 1.0]], io.waits)
  ensure
    pipe&.close
  end

  def test_each_run_takes_what_the_wait_found_ready
    pipe = IO.pipe.first
    watches = [Watch.new(:one, output: pipe, ends: true), Watch.new(:two)]

    assert_equal([[:one], 1], finished(*watches, io: Select.new([pipe])))
    assert_equal([[[pipe]], [[pipe]]], watches.map(&:taken))
  ensure
    pipe&.close
  end

  def test_a_run_starts_at_most_the_window_of_runs_at_once_and_finishes_every_one
    set = Stryker::Isolation::FreshWatches.new(Select.new)
    names = []
    running = []
    set.run(%i[one two three], 2) do |name|
      running << set.size
      set.add(Watch.new(name, done: true).finished_into(names))
    end

    assert_equal([%i[one two three], [0, 1, 0], 0], [names, running, set.size])
  end

  def test_an_empty_set_finishes_nothing_and_waits_for_nothing
    io = Select.new

    assert_equal([[], 0], finished(io:))
    assert_empty(io.waits)
  end

  def test_a_run_is_in_the_set_while_it_finishes_and_out_of_it_after
    set = Stryker::Isolation::FreshWatches.new(Select.new)
    sizes = []
    watch = Watch.new(:done, done: true)
    watch.define_singleton_method(:finish) { sizes << set.size }
    set.add(watch)
    set.finish

    assert_equal([[1], 0], [sizes, set.size])
  end

  def test_a_run_whose_finish_raises_is_still_in_the_set_for_stop_to_reach
    set = Stryker::Isolation::FreshWatches.new(Select.new)
    watch = Watch.new(:done, done: true)
    watch.define_singleton_method(:finish) { raise(ThreadError) }
    set.add(watch)

    assert_raises(ThreadError) { set.finish }
    assert_equal(1, set.size)
  end

  # Time that only moves when a wait moves it, and a process on it that
  # writes its first test's line at +test_at+ and ends at +ends_at+, in
  # seconds. It stands in for the process, the run's folder, the clock, and
  # `IO.select`.
  class Timeline
    attr_reader :now

    def initialize(test_at:, ends_at:)
      @test_at = test_at
      @ends_at = ends_at
      @now = 0.0
    end

    def select(readers, _writers, _errors, timeout)
      # The pipe has ended, so it is readable at once, and then nothing
      # wakes the wait but its timeout.
      return [readers, [], []] if readers.any?

      @now += timeout
      nil
    end

    def started?
      @now >= @test_at
    end

    def reap(_seconds = 0)
      nil
    end

    def reaped?
      @now >= @ends_at
    end

    def running?
      !reaped?
    end

    def end_now
      nil
    end

    def status
      IsolationStandIns::Exit.new(nil, 0)
    end

    def kill_rest
      nil
    end

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
  private_constant(:Timeline)

  # Whether the run of a process on +timeline+, with a time limit of
  # +milliseconds+, timed out, and the second on the timeline when it
  # landed, once the set has finished it. The process's pipe ended at once,
  # as when the process moves its standard output.
  def landed_on(timeline, milliseconds)
    timer = Stryker::Isolation::Timer.new(milliseconds, clock: timeline.method(:now))
    set = Stryker::Isolation::FreshWatches.new(timeline)
    landed = []
    set.add(running_fresh(timeline, timeline, timer) { |_, ending| landed << ending.timed_out })
    set.finish until set.empty?
    [*landed, timeline.now.round(1)]
  end

  def test_a_time_limit_starts_with_the_first_test_the_results_file_shows
    # The limit is shorter than the wait before the first test, as a fresh
    # process's start can be (#85), and longer than the test. The process
    # ends between two looks, and the run lands at the second.
    assert_equal([false, 5.3], landed_on(Timeline.new(test_at: 5.0, ends_at: 5.25), 1000))
  end

  def test_a_process_whose_pipe_ended_is_looked_at_until_it_ends_before_its_deadline
    assert_equal([false, 2.0], landed_on(Timeline.new(test_at: 0.0, ends_at: 1.95), 30_000))
  end

  def test_a_process_past_its_time_after_its_first_test_is_timed_out
    # The run's landing deletes the folder.
    folder = Dir.mktmpdir
    results = File.join(folder, "results")
    pid, reader = scripted("File.binwrite(#{results.dump}, %({\"started\":{}}\\n)); sleep")

    assert_equal([[true], false], [timed_out(folder, pid, reader, 300), File.exist?(folder)])
  end

  def test_a_process_that_ends_wakes_the_wait_at_once
    folder = Dir.mktmpdir
    pid, reader = scripted("$stdout.write('..')")
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    assert_equal([false], timed_out(folder, pid, reader, 30_000))
    assert_operator(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 30)
  end

  # Watches the process +pid+, whose folder is +folder+ and whose standard
  # output is +reader+, with a time limit of +milliseconds+, until it lands,
  # and gives whether it timed out.
  private def timed_out(folder, pid, reader, milliseconds)
    landed = []
    timer = Stryker::Isolation::Timer.new(milliseconds)
    set = Stryker::Isolation::FreshWatches.new
    output = Stryker::Isolation::OutputPipe.new(reader, File.join(folder, "process.out"))
    child = Stryker::Isolation::ChildProcess.new(pid)
    fresh = Stryker::Isolation::FreshFolder.new(folder)
    set.add(running_fresh(fresh, child, timer, output:) { |_, ending| landed << ending.timed_out })
    set.finish until set.empty?
    landed
  end
end
