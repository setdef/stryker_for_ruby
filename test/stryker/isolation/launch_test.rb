# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "stryker/isolation"
require "stryker/test_runners/recipe"
require "tmpdir"

# How the orchestrator starts its project processes, with a stand-in for
# Process, on every system: the parent that forks, and a fresh process for a
# static mutant's run.
class LaunchTest < Minitest::Test
  include IsolationStandIns

  RECIPE = Stryker::TestRunners::Recipe.new("minitest")
  private_constant(:RECIPE)

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
    parent = Stryker::Isolation::ParentLaunch.new("/cache", "/project", @process).call(RECIPE)
    environment, argv, = spawned

    assert_equal({ Stryker::Isolation::Command::ACTIVE_MUTANT => nil }, environment)
    assert_equal(%w[fork-parent /cache minitest {}], argv.last(6).first(4))
    assert_match(/\A\d+\z/, argv[-2])
  ensure
    parent&.stop
  end

  # Launches the parent with the stand-in, and returns what it was asked to
  # spawn with, and the parent.
  def parent_spawned
    parent = Stryker::Isolation::ParentLaunch.new("/cache", "/project", @process).call(RECIPE)
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
  # returns what it was asked to spawn with, the run's file, and the run.
  def fresh_spawned
    fresh = Stryker::Isolation::FreshRun.judged(sample_run(7, static: true), Stryker::Isolation::FreshFolder.made) { nil }
    fresh.launch(Stryker::Isolation::FreshLaunch.new("/cache", "/project", @process), RECIPE)
    environment, argv, options = spawned
    [environment, argv[-2], options, fresh]
  end

  def test_a_fresh_process_starts_with_its_mutant_active_and_its_run_in_a_file
    environment, run_file, _, fresh = fresh_spawned

    assert_equal({ Stryker::Isolation::Command::ACTIVE_MUTANT => "7" }, environment)
    assert_equal(sample_run(7, static: true), Stryker::MutantRun.from_json(File.read(run_file)))
  ensure
    fresh&.stop
  end

  def test_a_fresh_process_runs_in_the_project_with_its_output_in_the_runs_folder
    _, run_file, options, fresh = fresh_spawned

    assert_equal(
      [File::NULL, "/project", File.dirname(run_file)],
      [options[:in], options[:chdir], File.dirname(options[:err])]
    )
  ensure
    fresh&.stop
  end

  # A handle over a process that exited with status 1 before it wrote
  # anything.
  class Exited
    Status = Struct.new(:termsig, :exitstatus)
    private_constant(:Status)

    def initialize
      @running = false
    end

    def end_within(_seconds)
      @running
    end

    def status
      Status.new(nil, 1)
    end

    def kill_rest
      nil
    end
  end
  private_constant(:Exited)

  # The messages and the ending that a run in +folder+ lands with, once its
  # process has exited.
  def landed(folder)
    results = []
    fresh = running_fresh(folder, Exited.new, Stryker::Isolation::Timer.new(30_000)) { |*landing| results << landing }
    fresh.finish
    results.first
  end

  def test_a_fresh_run_whose_process_wrote_nothing_has_no_messages_and_leaves_no_folder
    folder = Stryker::Isolation::FreshFolder.made
    path = File.dirname(folder.paths(sample_run(7, static: true)).first)
    messages, ending = landed(folder)

    assert_equal([0, false, 1, false], [messages.results.size, messages.ended?, ending.exit_status, File.exist?(path)])
  end

  def test_a_fresh_run_has_started_a_test_once_its_results_begin_with_a_whole_start
    folder = Stryker::Isolation::FreshFolder.made
    results = folder.paths(sample_run(7, static: true)).last
    started = [folder.started?]
    File.binwrite(results, '{"started":')
    started << folder.started?
    File.binwrite(results, %({"started":{}}\n{"finished":))
    started << folder.started?

    assert_equal([false, false, true], started)
  ensure
    folder&.remove
  end

  def test_the_fresh_adapter_needs_starting_first_and_stops_without_a_start
    isolation = Stryker::Isolation::FreshProcesses.new("/cache")

    assert_raises(Stryker::Isolation::Error) { isolation.run_all([sample_run]) { nil } }
    assert_nil(isolation.stop)
  end
end
