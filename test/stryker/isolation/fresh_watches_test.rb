# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "stryker/isolation/fresh_folder"
require "stryker/isolation/fresh_run"
require "stryker/isolation/fresh_watches"
require "stryker/isolation/messages"

# Which fresh processes the set finishes: each that has ended or run out of
# time, after a wait for the one whose time ends first, which is short while
# any run hasn't started a test. The first tests use stand-ins for the
# watches; the last uses a real process.
class FreshWatchesTest < Minitest::Test
  include IsolationStandIns

  # A watch that ends after a wait when +ends+ says so, and notes how long
  # each wait was and whether it was checked for a test's start.
  class Watch
    attr_reader :name, :left, :waits, :checks

    def initialize(name, ended: false, left: 5.0, testing: true, ends: false)
      @name = name
      @ended = ended
      @left = left
      @testing = testing
      @ends = ends
      @waits = []
      @checks = 0
    end

    def check
      @checks += 1
    end

    def testing?
      @testing
    end

    def done?
      @ended
    end

    def wait(seconds)
      @waits << seconds
      @ended = @ends
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

  def finished(*watches)
    set = Stryker::Isolation::FreshWatches.new
    names = []
    watches.each { |watch| set.add(watch.finished_into(names)) }
    set.finish
    [names, set.size]
  end

  def test_each_process_that_ended_is_finished_and_no_other
    assert_equal([[:done], 1], finished(Watch.new(:running), Watch.new(:done, ended: true)))
  end

  def test_with_none_ended_the_set_waits_for_the_process_whose_time_ends_first
    later = Watch.new(:later, left: 9.0)
    soon = Watch.new(:soon, left: 1.0, ends: true)

    assert_equal([[:soon], 1], finished(later, soon))
    assert_equal([[], [1.0]], [later.waits, soon.waits])
  end

  def test_while_a_run_has_started_no_test_the_wait_is_short
    soon = Watch.new(:soon, left: 1.0)

    assert_equal([[], 2], finished(soon, Watch.new(:loading, left: 300.0, testing: false)))
    assert_equal([Stryker::Isolation::FreshWatches::POLL_SECONDS], soon.waits)
  end

  def test_a_run_starts_at_most_the_window_of_watches_at_once_and_finishes_every_one
    set = Stryker::Isolation::FreshWatches.new
    names = []
    running = []
    set.run(%i[one two three], 2) do |name|
      running << set.size
      set.add(Watch.new(name, ended: true).finished_into(names))
    end

    assert_equal([%i[one two three], [0, 1, 0], 0], [names, running, set.size])
  end

  def test_an_empty_set_finishes_nothing_and_waits_for_nothing
    assert_equal([[], 0], finished)
  end

  def test_a_watch_is_in_the_set_while_it_finishes_and_out_of_it_after
    set = Stryker::Isolation::FreshWatches.new
    sizes = []
    watch = Watch.new(:done, ended: true)
    watch.define_singleton_method(:finish) { sizes << set.size }
    set.add(watch)
    set.finish

    assert_equal([[1], 0], [sizes, set.size])
  end

  def test_a_watch_whose_finish_raises_is_still_in_the_set_for_stop_to_reach
    set = Stryker::Isolation::FreshWatches.new
    watch = Watch.new(:done, ended: true)
    watch.define_singleton_method(:finish) { raise(ThreadError) }
    set.add(watch)

    assert_raises(ThreadError) { set.finish }
    assert_equal(1, set.size)
  end

  def test_every_process_is_checked_for_its_first_test
    watches = [Watch.new(:one, ended: true), Watch.new(:two)]
    finished(*watches)

    assert_equal([1, 1], watches.map(&:checks))
  end

  # Time that only moves when a wait moves it, and a process on it that
  # writes its first test's line at +test_at+ and ends at +ends_at+, in
  # seconds. It stands in for the child, the run's folder, and the clock.
  class Timeline
    Done = Struct.new(:exitstatus, :termsig)
    private_constant(:Done)

    attr_reader :now

    def initialize(test_at:, ends_at:)
      @test_at = test_at
      @ends_at = ends_at
      @now = 0.0
    end

    def started?
      @now >= @test_at
    end

    def ended?
      @now >= @ends_at
    end

    def wait(seconds)
      @now = [@now + seconds, @ends_at].min
      nil
    end

    def end_within(seconds)
      wait(seconds)
      @running = !ended?
    end

    def status
      Done.new(0, nil)
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

  def test_a_time_limit_starts_with_the_first_test_the_results_file_shows
    # The limit is shorter than the wait before the first test, as a fresh
    # process's start can be (#85), and longer than the test.
    timeline = Timeline.new(test_at: 5.0, ends_at: 5.2)
    timer = Stryker::Isolation::Timer.new(1000, clock: timeline.method(:now))
    set = Stryker::Isolation::FreshWatches.new
    landed = []
    set.add(running_fresh(timeline, timeline, timer) { |_, ending| landed << ending.timed_out })
    set.finish until set.empty?

    assert_equal([false], landed)
  end

  def test_a_process_past_its_time_after_its_first_test_is_timed_out
    # The run's landing deletes the folder.
    folder = Dir.mktmpdir
    results = File.join(folder, "results")
    pid, = scripted("File.binwrite(#{results.dump}, %({\"started\":{}}\\n)); sleep")

    assert_equal([[true], false], [timed_out(folder, pid, 300), File.exist?(folder)])
  end

  # Watches the process +pid+, whose folder is +folder+, with a time limit of
  # +milliseconds+ until it lands, and gives whether it timed out.
  private def timed_out(folder, pid, milliseconds)
    landed = []
    timer = Stryker::Isolation::Timer.new(milliseconds)
    set = Stryker::Isolation::FreshWatches.new
    fresh = Stryker::Isolation::FreshFolder.new(folder)
    set.add(running_fresh(fresh, Stryker::Isolation::Child.new(pid), timer) { |_, ending| landed << ending.timed_out })
    set.finish until set.empty?
    landed
  end
end
