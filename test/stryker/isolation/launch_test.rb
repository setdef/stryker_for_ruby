# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "stryker/isolation"
require "tmpdir"

# How the orchestrator starts its project processes, with a stand-in for
# Process, on every system: the parent that forks, and a fresh process for a
# static mutant's run.
class LaunchTest < Minitest::Test
  include IsolationStandIns

  def setup
    super
    @process = FakeProcess.new
  end

  # The environment, the arguments, and the options of the process the
  # stand-in was asked to spawn.
  def spawned
    _, environment, *argv, options = @process.calls.first
    [environment, argv, options]
  end

  def test_the_parent_starts_with_no_mutant_active_and_its_results_on_a_descriptor_of_their_own
    parent = Stryker::Isolation::ParentLaunch.new("/cache", "/project", @process).call("minitest")
    environment, argv, = spawned

    assert_equal({ Stryker::Isolation::Command::ACTIVE_MUTANT => nil }, environment)
    assert_equal(%w[fork-parent /cache minitest], argv.last(5).first(3))
    assert_match(/\A\d+\z/, argv[-2])
  ensure
    parent&.stop
  end

  # Launches the parent with the stand-in, and returns what it was asked to
  # spawn with, and the parent.
  def parent_spawned
    parent = Stryker::Isolation::ParentLaunch.new("/cache", "/project", @process).call("minitest")
    [*spawned, parent]
  end

  def test_the_parent_runs_in_the_project_with_its_output_in_files_and_in_a_group_of_its_own
    _, argv, options, parent = parent_spawned

    assert_equal(Stryker::Isolation::OutputFiles.new(argv.last).paths("parent"), options.values_at(:out, :err))
    assert_equal(
      ["/project", Stryker::Isolation::ProcessGroup::SYSTEM.spawn_options],
      [options[:chdir], options.slice(:pgroup)]
    )
  ensure
    parent&.stop
  end

  def test_the_parent_gets_its_results_pipe_and_the_orchestrator_closes_its_own_end_of_it
    _, _, options, parent = parent_spawned
    output = options.keys.find { |key| key.is_a?(IO) }

    assert_equal([output, true], [options[output], output.closed?])
  ensure
    parent&.stop
  end

  # Launches a fresh process of mutant 7's static run with the stand-in, and
  # returns what it was asked to spawn with, the run's file, and the watch.
  def fresh_spawned
    watch = Stryker::Isolation::StaticLaunch.new("/cache", "/project", @process).call(
      sample_run(7, static: true),
      "minitest"
    )
    environment, argv, options = spawned
    [environment, argv[-2], options, watch]
  end

  def test_a_fresh_process_starts_with_its_mutant_active_and_its_run_in_a_file
    environment, run_file, _, watch = fresh_spawned

    assert_equal({ Stryker::Isolation::Command::ACTIVE_MUTANT => "7" }, environment)
    assert_equal(sample_run(7, static: true), Stryker::MutantRun.from_json(File.read(run_file)))
  ensure
    watch&.stop
  end

  def test_a_fresh_process_runs_in_the_project_with_its_output_in_the_runs_folder
    _, run_file, options, watch = fresh_spawned

    assert_equal(
      [File::NULL, "/project", File.dirname(run_file)],
      [options[:in], options[:chdir], File.dirname(options[:err])]
    )
  ensure
    watch&.stop
  end

  def test_a_fresh_run_whose_process_wrote_nothing_has_no_messages_and_leaves_no_folder
    fresh = Stryker::Isolation::FreshRun.new(sample_run(7, static: true))
    folder = File.dirname(fresh.paths.first)
    ending = Stryker::Isolation::Ending.new(exit_status: 1, signal: nil, timed_out: false, duration_ms: 1.0, errors: "")
    result = fresh.result(ending)

    assert_equal(["RuntimeError", 0, false], [result.status, result.tests_completed, File.exist?(folder)])
  end

  def test_the_fresh_adapter_needs_starting_first_and_stops_without_a_start
    isolation = Stryker::Isolation::FreshProcesses.new("/cache")

    assert_raises(Stryker::Isolation::Error) { isolation.run_all([sample_run]) { nil } }
    assert_nil(isolation.stop)
  end
end
