# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "minitest/mock"
require "stryker/isolation"
require "stryker/test_runners/recipe"
require "tmpdir"

# What the launch of a fresh process leaves behind when the system refuses to
# start the process, with a stand-in for Process, on every system.
class FreshLaunchTest < Minitest::Test
  include IsolationStandIns

  def setup
    super
    @temporary = Dir.mktmpdir("stryker-launch-test-")
  end

  def teardown
    FileUtils.remove_entry(@temporary)
  end

  # Makes the run, and launches its process with a process that refuses, with
  # the run's folder made inside `@temporary`.
  def refused_launch
    folder = Dir.method(:mktmpdir)
    in_temporary = -> (prefix) { folder.call(prefix, @temporary) }
    Dir.stub(:mktmpdir, in_temporary) do
      fresh = Stryker::Isolation::FreshRun.judged(sample_run(7, static: true)) { nil }
      refusing = Stryker::Isolation::FreshLaunch.new("/cache", "/nonexistent-root", RefusingProcess.new)

      assert_raises(Errno::ENOENT) { refusing.call(fresh, Stryker::TestRunners::Recipe.new("minitest")) }
    end
  end

  def test_a_launch_that_fails_leaves_no_folder
    refused_launch

    assert_empty(Dir.children(@temporary))
  end
end
