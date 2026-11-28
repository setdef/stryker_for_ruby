# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "stryker/isolation/error"
require "stryker/isolation/fresh_folder"
require "stryker/isolation/fresh_run"
require "stryker/isolation/output_pipe"
require "stryker/isolation/timer"

# What a fresh run does with its process: whether it timed out, and what
# finishing or stopping it leaves behind when something fails along the way:
# the process ended, its group killed once, and the run's folder deleted,
# whatever raised, once the run is stopped as the set of runs stops it. A
# stand-in stands for the process.
class FreshRunTest < Minitest::Test
  include IsolationStandIns

  # A process that has ended by the time anything asks, unless +running+
  # says it still runs, which fails where a test says: `end_now` raises
  # `waiting`, `status` raises `reading`, or `kill_rest` raises `killing`.
  # It notes the calls it gets, and whether the folder stood at each stop.
  class Child
    attr_reader :calls, :folder_stood_at_stop

    def initialize(folder, running: false, waiting: nil, reading: nil, killing: nil)
      @folder = folder
      @running = running
      @failures = { end_now: waiting, status: reading, kill_rest: killing }
      @calls = []
    end

    def reap(_seconds = 0)
      nil
    end

    def reaped?
      !@running
    end

    def running?
      @calls << :running?
      @running
    end

    def end_now
      noted(:end_now)
    end

    def status
      noted(:status)
      IsolationStandIns::Exit.new(nil, 0)
    end

    def kill_rest
      @folder_stood_at_stop = Dir.exist?(@folder)
      noted(:kill_rest)
    end

    def stop
      @calls << :stop
      @folder_stood_at_stop = Dir.exist?(@folder)
    end

    private def noted(call)
      @calls << call
      failure = @failures[call]
      raise(failure) if failure
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
      [%i[running? end_now status kill_rest], true, false],
      [@child.calls, @child.folder_stood_at_stop, Dir.exist?(@path)]
    )
  end

  def test_a_process_that_was_reaped_has_its_group_killed_once_when_the_kill_raises
    run = fresh(killing: ThreadError)

    assert_raises(ThreadError) { run.finish }
    run.stop

    assert_equal([%i[running? end_now status kill_rest], false], [@child.calls, Dir.exist?(@path)])
  end

  def test_a_signal_while_a_finish_ends_the_process_leaves_the_process_to_stop_before_the_folder_goes
    run = fresh(running: true, waiting: Interrupt)

    assert_raises(Interrupt) { run.finish }
    run.stop

    assert_equal(
      [%i[running? end_now stop], true, false],
      [@child.calls, @child.folder_stood_at_stop, Dir.exist?(@path)]
    )
  end

  def test_a_finish_that_lands_stops_nothing_and_leaves_no_folder
    fresh.finish

    assert_equal([%i[running? end_now status kill_rest], 1, false], [@child.calls, @landed.size, Dir.exist?(@path)])
  end

  def test_a_process_still_running_when_its_run_finishes_timed_out_and_one_that_ended_did_not
    timed_out = [true, false].map do |running|
      landed = []
      run = running_fresh(@folder, Child.new(@path, running:), Stryker::Isolation::Timer.new(30_000)) do |_, ending|
        landed << ending
      end
      run.finish
      landed.first.timed_out
    end

    assert_equal([true, false], timed_out)
  end

  def test_a_landing_that_raises_stops_nothing_again_and_leaves_no_folder
    run = fresh { raise(ThreadError) }

    assert_raises(ThreadError) { run.finish }
    run.stop

    assert_equal([%i[running? end_now status kill_rest], false], [@child.calls, Dir.exist?(@path)])
  end

  def test_a_stop_whose_process_fails_to_end_still_deletes_the_folder
    run = fresh
    @child.define_singleton_method(:stop) { raise(ThreadError) }

    assert_raises(ThreadError) { run.stop }
    refute(Dir.exist?(@path))
  end

  def test_a_stop_after_a_finish_that_landed_stops_nothing_again
    fresh.tap(&:finish).stop

    assert_equal(%i[running? end_now status kill_rest], @child.calls)
  end

  def test_a_stop_ends_the_process_once_and_deletes_the_folder
    fresh.tap(&:stop).stop

    assert_equal([[:stop], false], [@child.calls, Dir.exist?(@path)])
  end

  def test_a_run_whose_process_never_started_can_take_no_event_of_a_running_one
    run = Stryker::Isolation::FreshRun.new(sample_run(7, static: true), @folder) { nil }
    error = assert_raises(Stryker::Isolation::Error) { run.wake_in }

    assert_equal(
      "A fresh run in the stage Stryker::Isolation::FreshRun::Made got wake_in, which that stage doesn't take.",
      error.message
    )
  end

  # Every event that a stage may take but stop, with its arguments.
  EVENTS = [[:spawn, nil, nil, nil], [:output], [:take, []], [:wake_in], [:done?], [:reap], [:land, nil]].freeze
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
