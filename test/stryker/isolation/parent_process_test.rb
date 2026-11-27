# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "fileutils"
require "stryker/isolation"
require "tmpdir"

# What the orchestrator does when it stops the parent that forks, with a
# stand-in for Process that records the kills, so the tests run the same on
# every system.
class ParentProcessTest < Minitest::Test
  include IsolationStandIns

  parallelize_me!

  # Stops a parent whose process has ended, and returns what it asked of
  # +process+ and the folder it was given.
  def stopped(process)
    folder = Dir.mktmpdir("stryker-fork-")
    input, commands = IO.pipe
    results, output = IO.pipe
    [input, output].each(&:close)
    child = Stryker::Isolation::Child.new(FakeProcess::PID, process)
    Stryker::Isolation::ParentProcess.new(child, [commands, results], folder).stop
    folder
  end

  def kills
    return [[:kill, :KILL, -FakeProcess::PID]] if Stryker::Isolation::ProcessGroup::SYSTEM.groups?

    []
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
