# frozen_string_literal: true

require_relative("../../support/project_side_stand_ins")
require "stringio"
require "stryker/isolation/project_process"
require "tmpdir"

# What the code in a project process does, with stand-ins for what would
# fork, end the process, or load the project, so each part runs in this
# process on every system: the forking, a forked child's run, a static
# mutant's run, and the entry point.
class ProjectSideTest < Minitest::Test
  include IsolationStandIns
  include ProjectSideStandIns

  def kinds(text)
    text.lines.map { |line| JSON.parse(line).keys.first }
  end

  def open_handles(path)
    ObjectSpace.each_object(File).count { |file| !file.closed? && file.path == path }
  end

  # Runs a static run of mutant 5 with mutant +active+ active, and returns
  # the runner, the finisher, the lines it wrote, and how many handles on its
  # results file are still open.
  def static_run(active)
    Dir.mktmpdir do |folder|
      paths = %w[0.run 0.results].map { |name| File.join(folder, name) }
      File.binwrite(paths.first, sample_run(5, static: true).to_json)
      runner = Runner.new("failed")
      finisher = Finisher.new
      Stryker::Isolation::StaticRun.build(runner, paths).call(finisher, Stryker::Runtime::ActiveMutant.new(id: active))
      [runner, finisher, File.read(paths.last), open_handles(paths.last)]
    end
  end

  def test_a_static_run_loads_the_tests_runs_its_run_and_writes_each_test
    runner, finisher, written = static_run(5)

    assert_equal([[:load_tests], [:run, ["SampleTest#test_value"], true]], runner.calls)
    assert_equal([0, %w[started finished ended]], [finisher.code, kinds(written)])
  end

  def test_a_static_run_of_another_mutant_than_the_active_one_runs_no_test
    runner, finisher, written = static_run(6)

    assert_equal([[], 1], [runner.calls, finisher.code])
    assert_includes(JSON.parse(written)["error"], "mutant 6 active")
  end

  def test_a_static_run_that_returns_leaves_no_open_handle_on_its_results_file
    *, open_handles = static_run(5)

    assert_equal(0, open_handles)
  end

  def test_the_entry_point_empties_argv_installs_the_loader_and_runs_its_mode
    argv = %w[static /cache minitest 0.run 0.results]
    loader = Loader.new

    assert_equal(
      :called,
      Stryker::Isolation::ProjectProcess.main(argv, loader, { static: Mode }.transform_keys(&:to_s))
    )
    assert_equal([[], "/cache"], [argv, loader.installed])
  end

  def test_the_entry_point_refuses_a_mode_or_a_test_runner_it_does_not_know
    assert_raises(ArgumentError) { Stryker::Isolation::ProjectProcess.main(%w[pool /cache minitest], Loader.new) }
    assert_raises(ArgumentError) { Stryker::Isolation::ProjectProcess.main(%w[static /cache rspec], Loader.new) }
  end

  def test_the_modes_build_from_their_arguments
    assert_kind_of(Stryker::Isolation::StaticRun, Stryker::Isolation::StaticRun.build(Runner.new, %w[0.run 0.results]))
  end
end
