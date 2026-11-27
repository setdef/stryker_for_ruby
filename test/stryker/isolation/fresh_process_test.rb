# frozen_string_literal: true

require_relative("../../support/project_side_stand_ins")
require "stryker/isolation/project_process"
require "tmpdir"

# What a fresh process does with the run in its file, with stand-ins for what
# would end the process or load the project, so it runs in this process on
# every system: a mutant run, and the dry run.
class FreshProcessTest < Minitest::Test
  include IsolationStandIns
  include ProjectSideStandIns

  Outcome = Data.define(:calls, :code, :lines, :open_handles)
  private_constant(:Outcome)

  # Runs a fresh process whose file holds +run+, with +holder+ holding the
  # active mutant, and +runner+, and gives the runner's calls, the code that
  # would end the process, the lines it wrote, and how many handles on its
  # results file are still open.
  def fresh(run, holder, runner)
    Dir.mktmpdir do |folder|
      paths = %w[run results].map { |name| File.join(folder, name) }
      File.binwrite(paths.first, run.to_json)
      finisher = Finisher.new
      Stryker::Isolation::FreshProcess.build(runner, paths).call(finisher, holder, DryRunTests)
      Outcome.new(runner.calls, finisher.code, *written(paths.last))
    end
  end

  # The lines written to the results file at +path+, and how many handles on
  # it are still open.
  def written(path)
    handles = ObjectSpace.each_object(File).count { |file| !file.closed? && file.path == path }
    [File.read(path).lines.map { |line| JSON.parse(line) }, handles]
  end

  def active(id)
    Stryker::Runtime::ActiveMutant.new(id:)
  end

  def kinds(outcome)
    outcome.lines.map { |line| line.keys.first }
  end

  # A static run of mutant 5, with mutant +id+ active.
  def static_run(id)
    fresh(sample_run(5, static: true), active(id), Runner.new("failed"))
  end

  # The dry run of the tests A#test_a and B#test_b, with +holder+ holding the
  # active mutant.
  def dry_run(holder)
    fresh(Stryker::Isolation::DryRun.within(5), holder, Runner.new("passed", %w[A#test_a B#test_b]))
  end

  def test_a_static_run_loads_the_tests_runs_its_run_and_writes_each_test
    outcome = static_run(5)

    assert_equal([[:load_tests], [:run, ["SampleTest#test_value"], true]], outcome.calls)
    assert_equal([0, %w[started finished ended]], [outcome.code, kinds(outcome)])
  end

  def test_a_static_run_of_another_mutant_than_the_active_one_runs_no_test
    outcome = static_run(6)

    assert_equal([[], 1], [outcome.calls, outcome.code])
    assert_includes(outcome.lines.last["error"], "mutant 6 active")
  end

  def test_a_run_that_returns_leaves_no_open_handle_on_its_results_file
    assert_equal(0, static_run(5).open_handles)
  end

  def test_the_dry_run_loads_the_tests_runs_each_once_and_writes_what_it_found
    outcome = dry_run(Stryker::Runtime::Recording.new(collector: nil))

    assert_equal([[:load_tests], [:run, %w[A#test_a B#test_b], true]], outcome.calls)
    assert_equal([0, %w[started finished started finished result ended]], [outcome.code, kinds(outcome)])
    assert_equal(%w[A#test_a B#test_b], outcome.lines.dig(4, "result", "buckets").keys)
  end

  def test_tests_that_raise_while_they_load_are_marked_as_failing_to_load
    runner = Runner.new("passed", NameError.new("uninitialized constant Shop"))
    outcome = fresh(Stryker::Isolation::DryRun.within(5), Stryker::Runtime::Recording.new(collector: nil), runner)

    assert_equal([1, %w[load_error error]], [outcome.code, kinds(outcome)])
    assert_equal("NameError: uninitialized constant Shop", outcome.lines.first["load_error"])
  end

  def test_the_dry_run_with_a_mutant_active_runs_no_test
    outcome = dry_run(active(4))

    assert_equal([[], 1], [outcome.calls, outcome.code])
    assert_includes(
      outcome.lines.last["error"],
      'mutant 4 active, from STRYKER_ACTIVE_MUTANT, and its run, {"dry_run":true}, needs mutant nil.'
    )
  end
end
