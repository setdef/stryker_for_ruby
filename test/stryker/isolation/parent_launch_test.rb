# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "minitest/mock"
require "rbconfig"
require "stryker/isolation"
require "stryker/test_runners/recipe"
require "tmpdir"

# What the launch of the fork parent leaves behind when the system refuses to
# start the process, with a stand-in for Process, on every system.
class ParentLaunchTest < Minitest::Test
  include IsolationStandIns

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

  # Starts a process that waits, in place of the parent, and then fails the
  # way a test says: `detach` raises, or, with `interrupted`, an Interrupt
  # arrives for the launching thread as `spawn` returns.
  class StartedThenFailing
    attr_reader :pid

    def initialize(test, interrupted: false)
      @test = test
      @interrupted = interrupted
    end

    def spawn(*)
      @pid = @test.start_process(RbConfig.ruby, "-e", "sleep")
      Thread.current.raise(Interrupt) if @interrupted
      @pid
    end

    def detach(_pid)
      raise(ThreadError)
    end

    def kill(*)
      Process.kill(*)
    end

    def wait(pid)
      Process.wait(pid)
    end
  end
  private_constant(:StartedThenFailing)

  # Launches the parent with `process`, which raises `expected`, with its
  # folder made inside `@temporary`.
  def launched_with(process, expected)
    folder = Dir.method(:mktmpdir)
    in_temporary = -> (prefix) { folder.call(prefix, @temporary) }
    Dir.stub(:mktmpdir, in_temporary) do
      launch = Stryker::Isolation::ParentLaunch.new("/cache", @temporary, process)
      assert_raises(expected) { launch.call(Stryker::TestRunners::Recipe.new("minitest")) }
    end
  end

  # Whether the process has ended and been reaped, without waiting for it.
  def ended?(pid)
    Process.wait(pid, Process::WNOHANG)
    false
  rescue Errno::ECHILD
    true
  end

  def test_a_launch_that_fails_after_the_process_started_ends_the_process_and_deletes_the_folder
    process = StartedThenFailing.new(self)
    launched_with(process, ThreadError)

    assert_equal([[], true], [Dir.children(@temporary), ended?(process.pid)])
  end

  def test_an_interrupt_as_the_process_starts_ends_the_process_and_deletes_the_folder
    process = StartedThenFailing.new(self, interrupted: true)
    launched_with(process, Interrupt)

    assert_equal([[], true], [Dir.children(@temporary), ended?(process.pid)])
  end
end
