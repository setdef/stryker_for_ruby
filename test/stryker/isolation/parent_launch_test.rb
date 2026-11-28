# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "minitest/mock"
require "stryker/isolation"
require "stryker/test_runners/recipe"
require "tmpdir"

# What the launch of the fork parent leaves behind when the system refuses to
# start the process, with a stand-in for Process, on every system.
class ParentLaunchTest < Minitest::Test
  include IsolationStandIns

  # Spawns nothing, and raises the error that a missing project root makes.
  class RefusingProcess
    def spawn(*)
      raise(Errno::ENOENT, "the project's root")
    end
  end

  def setup
    super
    @temporary = Dir.mktmpdir("stryker-launch-test-")
  end

  def teardown
    FileUtils.remove_entry(@temporary)
  end

  # Launches the parent with a process that refuses, with its folder made
  # inside `@temporary`, and returns the pipes that the launch made, in the
  # order it made them: the runs', then the results'.
  def refused_launch
    pipes = [IO.pipe, IO.pipe]
    queue = pipes.dup
    folder = Dir.method(:mktmpdir)
    in_temporary = -> (prefix) { folder.call(prefix, @temporary) }
    Dir.stub(:mktmpdir, in_temporary) { IO.stub(:pipe, -> { queue.shift }) { launch } }
    pipes.flatten
  end

  def launch
    refusing = Stryker::Isolation::ParentLaunch.new("/cache", "/nonexistent-root", RefusingProcess.new)

    assert_raises(Errno::ENOENT) { refusing.call(Stryker::TestRunners::Recipe.new("minitest")) }
  end

  def test_a_launch_that_fails_leaves_no_folder
    refused_launch

    assert_empty(Dir.children(@temporary))
  end

  def test_a_launch_that_fails_leaves_no_pipe_open
    pipes = refused_launch

    assert_equal([true] * 4, pipes.map(&:closed?))
  ensure
    pipes&.each { |pipe| pipe.close unless pipe.closed? }
  end
end
