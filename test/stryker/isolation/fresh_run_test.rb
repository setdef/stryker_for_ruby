# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "stryker/isolation/fresh_folder"
require "stryker/isolation/fresh_run"
require "stryker/isolation/timer"

# What finishing or stopping a fresh run leaves behind when something fails
# along the way: the process ended, its group killed once, and the run's
# folder deleted, whatever raised, once the run is stopped as the set of runs
# stops it. A stand-in stands for the handle over the process.
class FreshRunTest < Minitest::Test
  include IsolationStandIns

  Status = Struct.new(:termsig, :exitstatus)
  private_constant(:Status)

  # A handle over a process that ends at once, which fails where a test says:
  # `end_within` raises `waiting`, `status` raises `reading`, or `kill_rest` raises `killing`. It notes the
  # calls it gets, and whether the folder stood at each stop.
  class Child
    attr_reader :calls, :folder_stood_at_stop

    def initialize(folder, waiting: nil, reading: nil, killing: nil)
      @folder = folder
      @waiting = waiting
      @reading = reading
      @killing = killing
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
      @folder_stood_at_stop = Dir.exist?(@folder)
      raise(@killing) if @killing
    end

    def stop
      @calls << :stop
      @folder_stood_at_stop = Dir.exist?(@folder)
    end
  end
  private_constant(:Child)

  def setup
    @landed = []
    @folder = Stryker::Isolation::FreshFolder.made
    @path = File.dirname(@folder.paths(sample_run(7, static: true)).first)
  end

  def teardown
    @folder.remove
  end

  def fresh(**failure, &landing)
    @child = Child.new(@path, **failure)
    landing ||= -> (_messages, ending) { @landed << ending }
    running_fresh(@folder, @child, Stryker::Isolation::Timer.new(30_000), &landing)
  end

  def test_a_finish_that_raises_before_the_landing_kills_the_group_and_deletes_the_folder
    run = fresh(reading: ThreadError)

    assert_raises(ThreadError) { run.finish }
    run.stop

    assert_equal(
      [%i[end_within status kill_rest], true, false],
      [@child.calls, @child.folder_stood_at_stop, Dir.exist?(@path)]
    )
  end

  def test_a_process_that_was_reaped_has_its_group_killed_once_when_the_kill_raises
    run = fresh(killing: ThreadError)

    assert_raises(ThreadError) { run.finish }
    run.stop

    assert_equal([%i[end_within status kill_rest], false], [@child.calls, Dir.exist?(@path)])
  end

  def test_a_signal_while_a_finish_waits_for_the_process_leaves_the_process_to_stop_before_the_folder_goes
    run = fresh(waiting: Interrupt)

    assert_raises(Interrupt) { run.finish }
    run.stop

    assert_equal([%i[end_within stop], true, false], [@child.calls, @child.folder_stood_at_stop, Dir.exist?(@path)])
  end

  def test_a_finish_that_lands_stops_nothing_and_leaves_no_folder
    fresh.finish

    assert_equal([%i[end_within status kill_rest], 1, false], [@child.calls, @landed.size, Dir.exist?(@path)])
  end

  def test_a_landing_that_raises_stops_nothing_again_and_leaves_no_folder
    run = fresh { raise(ThreadError) }

    assert_raises(ThreadError) { run.finish }
    run.stop

    assert_equal([%i[end_within status kill_rest], false], [@child.calls, Dir.exist?(@path)])
  end

  def test_a_stop_whose_process_fails_to_end_still_deletes_the_folder
    run = fresh
    @child.define_singleton_method(:stop) { raise(ThreadError) }

    assert_raises(ThreadError) { run.stop }
    refute(Dir.exist?(@path))
  end

  def test_a_stop_after_a_finish_that_landed_stops_nothing_again
    fresh.tap(&:finish).stop

    assert_equal(%i[end_within status kill_rest], @child.calls)
  end

  def test_a_stop_ends_the_process_once_and_deletes_the_folder
    fresh.tap(&:stop).stop

    assert_equal([[:stop], false], [@child.calls, Dir.exist?(@path)])
  end

  def test_a_run_whose_process_never_started_can_take_no_event_of_a_running_one
    run = Stryker::Isolation::FreshRun.new(sample_run(7, static: true), @folder) { nil }
    error = assert_raises(Stryker::Isolation::Error) { run.left }

    assert_equal(
      "A fresh run in the stage Stryker::Isolation::FreshRun::Made got left, which that stage doesn't take.",
      error.message
    )
  end

  # Every event that a stage may take but stop, with its arguments.
  EVENTS = [
    [:spawn, nil, nil, nil],
    [:hold, 1],
    [:check],
    [:testing?],
    [:done?],
    [:wait, 1.0],
    [:left],
    [:reap],
    [:land, nil],
  ].freeze
  private_constant(:EVENTS)

  def test_a_stage_with_nothing_left_takes_only_a_stop
    stage = Stryker::Isolation::FreshRun::Stage.new
    refused = EVENTS.filter_map do |event, *arguments|
      stage.public_send(event, *arguments)
    rescue Stryker::Isolation::Error => e
      e.message.include?("got #{event},") && event
    end

    assert_equal([EVENTS.map(&:first), nil], [refused, stage.stop])
  end
end
