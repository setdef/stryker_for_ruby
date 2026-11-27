# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "fileutils"
require "json"
require "stryker/isolation"
require "tmpdir"

# What the orchestrator does when it stops the parent that forks, with a
# stand-in for Process that records the kills, so the tests run the same on
# every system.
class ParentProcessTest < Minitest::Test
  include IsolationStandIns

  parallelize_me!

  # A parent whose process has ended, with +process+ as its stand-in for
  # Process and +folder+ for its output. Nothing reads its runs' pipe.
  def ended_parent(process, folder)
    input, commands = IO.pipe
    results, output = IO.pipe
    [input, output].each(&:close)
    child = Stryker::Isolation::Child.new(FakeProcess::PID, process)
    Stryker::Isolation::ParentProcess.new(child, [commands, results], folder)
  end

  # Stops a parent whose process has ended, and returns what it asked of
  # +process+ and the folder it was given.
  def stopped(process)
    folder = Dir.mktmpdir("stryker-fork-")
    ended_parent(process, folder).stop
    folder
  end

  # Awaits a parent that says +said+ as its first line, with +errors+ as the
  # end of its standard error, and returns the error that this raises.
  def awaited(said, errors = nil)
    # Not Dir.mktmpdir's block: ParentProcess#stop deletes the folder when
    # await_ready raises, and before Ruby 4.1 the block's cleanup raises
    # Errno::ENOENT for a folder that is gone.
    folder = Dir.mktmpdir("stryker-fork-")
    File.binwrite(Stryker::Isolation::OutputFiles.new(folder).paths("parent").last, errors) if errors
    pid, results = scripted("puts(#{JSON.generate(said).inspect})")
    _, commands = IO.pipe
    parent = Stryker::Isolation::ParentProcess.new(Stryker::Isolation::Child.new(pid), [commands, results], folder)
    assert_raises(Stryker::Isolation::Error, Stryker::Isolation::TestsLoadError) { parent.await_ready }
  ensure
    FileUtils.rm_rf(folder) if folder
  end

  # Gives a run to a parent that ended, whose standard error ended with
  # +errors+, and returns the error that this raises.
  def given_to_an_ended_parent(errors = nil)
    folder = Dir.mktmpdir("stryker-fork-")
    File.binwrite(Stryker::Isolation::OutputFiles.new(folder).paths("parent").last, errors) if errors
    parent = ended_parent(FakeProcess.new, folder)
    assert_raises(Stryker::Isolation::Error) { parent.give(sample_run) }
  ensure
    parent&.stop
  end

  def kills
    return [[:kill, :KILL, -FakeProcess::PID]] if Stryker::Isolation::ProcessGroup::SYSTEM.groups?

    []
  end

  def test_a_parent_that_says_the_tests_raised_loading_raises_what_they_raised_and_the_end_of_its_standard_error
    error = awaited({ load_error: "NameError: Minitest" }, "first line\nlast line\n")

    assert_instance_of(Stryker::Isolation::TestsLoadError, error)
    assert_equal(
      "The project's tests failed to load, so no mutant can run. They raised:\nNameError: Minitest\n" \
        "The end of the process's standard error:\nfirst line\nlast line",
      error.message
    )
  end

  def test_a_parent_that_says_the_tests_raised_loading_and_wrote_no_standard_error_raises_what_they_raised_alone
    error = awaited({ load_error: "NameError: Minitest" })

    assert_equal(
      "The project's tests failed to load, so no mutant can run. They raised:\nNameError: Minitest",
      error.message
    )
  end

  def test_a_parent_that_says_error_before_it_is_ready_raises_a_fault_of_this_gem_whatever_the_error_says
    error = awaited({ error: "NameError: Minitest" })

    assert_instance_of(Stryker::Isolation::Error, error)
    assert_includes(error.message, "NameError: Minitest")
  end

  def test_giving_a_run_to_a_parent_that_ended_raises_an_error_that_says_so_with_the_end_of_its_standard_error
    error = given_to_an_ended_parent("first line\nlast line\n")

    assert_equal("The fork parent ended before it took a run.\nfirst line\nlast line", error.message)
  end

  def test_giving_a_run_to_a_parent_that_ended_without_writing_standard_error_raises_an_error_that_says_so
    assert_equal("The fork parent ended before it took a run.", given_to_an_ended_parent.message)
  end

  def test_stopping_the_parent_ends_what_the_projects_code_started_in_its_group
    process = FakeProcess.new
    stopped(process)

    assert_equal([[:detach, FakeProcess::PID], *kills], process.calls)
  end

  def test_stopping_the_parent_deletes_its_folder
    folder = stopped(FakeProcess.new)

    refute_path_exists(folder)
  ensure
    FileUtils.remove_entry(folder, true) if folder
  end
end
