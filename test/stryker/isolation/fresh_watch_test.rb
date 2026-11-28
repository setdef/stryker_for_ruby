# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "stryker/isolation/fresh_run"
require "stryker/isolation/fresh_watch"
require "stryker/isolation/timer"

# What finishing or stopping a fresh process leaves behind when something
# fails along the way: the process ended and the run's folder deleted,
# whatever raised, with stand-ins for the handle over the process.
class FreshWatchTest < Minitest::Test
  include IsolationStandIns

  Status = Struct.new(:termsig, :exitstatus)
  private_constant(:Status)

  # A handle over a process that ends at once, which fails where a test says:
  # `end_within` raises `waiting`, or `status` raises `reading`. It notes the
  # calls it gets, and whether the folder stood at each stop.
  class Child
    attr_reader :calls, :folder_stood_at_stop

    def initialize(folder, waiting: nil, reading: nil)
      @folder = folder
      @waiting = waiting
      @reading = reading
      @calls = []
      @running = false
    end

    def end_within(_seconds)
      @calls << :end_within
      raise(@waiting) if @waiting

      @running
    end

    def status
      @calls << :status
      raise(@reading) if @reading

      Status.new(nil, 0)
    end

    def kill_rest
      @calls << :kill_rest
    end

    def stop
      @calls << :stop
      @folder_stood_at_stop = Dir.exist?(@folder)
    end
  end
  private_constant(:Child)

  def setup
    @landed = []
    @fresh = Stryker::Isolation::FreshRun.judged(sample_run(7, static: true)) { |result| @landed << result.status }
    @folder = File.dirname(@fresh.paths.first)
  end

  def teardown
    @fresh.remove
  end

  def watch(**failure)
    @child = Child.new(@folder, **failure)
    Stryker::Isolation::FreshWatch.new(@fresh, @child, Stryker::Isolation::Timer.new(30_000))
  end

  def test_a_finish_that_raises_before_the_landing_ends_the_process_and_deletes_the_folder
    assert_raises(ThreadError) { watch(reading: ThreadError).finish }

    assert_equal(
      [%i[end_within status stop], true, false],
      [@child.calls, @child.folder_stood_at_stop, Dir.exist?(@folder)]
    )
  end

  def test_a_signal_while_a_finish_waits_for_the_process_ends_the_process_and_deletes_the_folder
    assert_raises(Interrupt) { watch(waiting: Interrupt).finish }

    assert_equal([%i[end_within stop], true, false], [@child.calls, @child.folder_stood_at_stop, Dir.exist?(@folder)])
  end

  def test_a_finish_that_lands_stops_nothing_and_leaves_no_folder
    watch.finish

    assert_equal([%i[end_within status kill_rest], 1, false], [@child.calls, @landed.size, Dir.exist?(@folder)])
  end

  def test_a_landing_that_raises_stops_nothing_again_and_leaves_no_folder
    fresh = Stryker::Isolation::FreshRun.judged(sample_run(8, static: true)) { raise(ThreadError) }
    folder = File.dirname(fresh.paths.first)
    child = Child.new(folder)

    assert_raises(ThreadError) { Stryker::Isolation::FreshWatch.new(fresh, child, Stryker::Isolation::Timer.new(30_000)).finish }
    assert_equal([%i[end_within status kill_rest], false], [child.calls, Dir.exist?(folder)])
  end

  def test_a_stop_after_a_finish_that_landed_stops_nothing_again
    watch.tap(&:finish).stop

    assert_equal(%i[end_within status kill_rest], @child.calls)
  end

  def test_a_stop_ends_the_process_once_and_deletes_the_folder
    watch.tap(&:stop).stop

    assert_equal([[:stop], false], [@child.calls, Dir.exist?(@folder)])
  end
end
