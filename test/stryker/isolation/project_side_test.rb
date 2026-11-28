# frozen_string_literal: true

require_relative("../../support/project_side_stand_ins")
require "stringio"
require "stryker/isolation/project_process"
require "tmpdir"

# What the code in a project process does, with stand-ins for what would
# fork, end the process, or load the project, so each part runs in this
# process on every system: the forking, a forked child's run, and the entry
# point.
class ProjectSideTest < Minitest::Test
  include IsolationStandIns
  include ProjectSideStandIns

  def kinds(text)
    text.lines.map { |line| JSON.parse(line).keys.first }
  end

  def test_forking_forks_a_child_with_a_pipe_of_its_own
    process = FakeProcess.new
    pid, reader = Stryker::Isolation::Forking.new(nil, process).start(sample_run, nil)

    # The child's own setpgid may run after a KILL, which then finds no group,
    # so the parent puts the child in its group too.
    assert_equal([FakeProcess::PID, [[:fork], [:setpgid, FakeProcess::PID, FakeProcess::PID]]], [pid, process.calls])
    assert_kind_of(IO, reader)
  ensure
    reader&.close
  end

  def test_forking_a_child_that_has_ended_already_is_no_error
    [Errno::ESRCH, Errno::EACCES, Errno::EPERM].each do |error|
      process = FakeProcess.new(setpgid_error: error)
      pid, reader = Stryker::Isolation::Forking.new(nil, process).start(sample_run, nil)

      assert_equal(FakeProcess::PID, pid)
      reader.close
    end
  end

  def test_a_forked_child_leads_a_group_changes_its_streams_and_runs_its_run
    process = FakeProcess.new
    streams = Calls.new
    forked_run = Calls.new
    Stryker::Isolation::Forking.new(streams, process).child(sample_run(7), forked_run, :writer)

    assert_equal([[[:setpgid, 0, 0]], [["7"]]], [process.calls, streams.calls])
    assert_equal([[:writer]], forked_run.calls)
  end

  def test_forking_gives_the_end_of_each_childs_standard_error
    Dir.mktmpdir do |folder|
      File.binwrite(File.join(folder, "7.err"), "[BUG] crash\n")
      streams = Stryker::Isolation::ForkedStreams.new(StringIO.new, Stryker::Isolation::OutputFiles.new(folder))

      assert_equal(
        "[BUG] crash\n",
        Stryker::Isolation::Forking.new(streams, FakeProcess.new).errors(sample_run(7))
      )
    end
  end

  def test_a_forked_run_makes_its_mutant_active_and_writes_each_test
    runner = Runner.new
    runtime = Runtime.new
    writer = StringIO.new
    Stryker::Isolation::ForkedRun.new(runner, sample_run(9), Finisher.new, runtime).call(writer)

    assert_equal([9, [[:run, ["SampleTest#test_value"], true]]], [runtime.active, runner.calls])
    assert_equal(%w[started finished ended], kinds(writer.string))
  end

  def test_the_entry_point_empties_argv_installs_the_loader_and_runs_its_mode
    argv = %w[fresh /cache minitest {} 0.run 0.results]
    loader = Loader.new

    assert_equal(
      :called,
      Stryker::Isolation::ProjectProcess.main(argv, loader, { fresh: Mode }.transform_keys(&:to_s))
    )
    assert_equal([[], "/cache"], [argv, loader.installed])
  end

  def test_the_entry_point_refuses_a_mode_or_a_test_runner_it_does_not_know
    assert_raises(ArgumentError) { Stryker::Isolation::ProjectProcess.main(%w[pool /cache minitest {}], Loader.new) }
    assert_raises(ArgumentError) { Stryker::Isolation::ProjectProcess.main(%w[fresh /cache rspec {}], Loader.new) }
  end

  def test_the_modes_build_from_their_arguments
    reader, writer = IO.pipe
    parent = Stryker::Isolation::ForkParent.build(Runner.new, [writer.fileno.to_s, Dir.tmpdir])
    fresh = Stryker::Isolation::FreshProcess.build(Runner.new, %w[0.run 0.results])

    assert_kind_of(Stryker::Isolation::ForkParent, parent)
    assert_kind_of(Stryker::Isolation::FreshProcess, fresh)
  ensure
    [reader, writer].each { |io| io&.close }
  end
end
