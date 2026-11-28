# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "minitest/mock"
require "rbconfig"
require "stryker/isolation"
require "stryker/test_runners/recipe"
require "tmpdir"

# What the launch of a fresh process leaves behind when something fails, with
# a stand-in for Process, on every system.
class FreshLaunchTest < Minitest::Test
  include IsolationStandIns

  # Starts a process that waits, in place of the project's, and then fails the
  # way a test says: `detach` raises `error`, or, with `interrupted`, an
  # Interrupt arrives for the launching thread as `spawn` returns. It notes
  # whether the run's folder still stood when the process was killed.
  class StartedThenFailing
    attr_reader :pid, :folder_stood_at_kill

    def initialize(test, folder, error: nil, interrupted: false)
      @test = test
      @folder = folder
      @error = error
      @interrupted = interrupted
    end

    def spawn(*)
      @pid = @test.start_process(RbConfig.ruby, "-e", "sleep")
      Thread.current.raise(Interrupt) if @interrupted
      @pid
    end

    def detach(_pid)
      raise(@error) if @error

      Process.detach(@pid)
    end

    def kill(*)
      @folder_stood_at_kill = Dir.exist?(@folder.call)
      Process.kill(*)
    end

    def wait(pid)
      Process.wait(pid)
    end
  end
  private_constant(:StartedThenFailing)

  def setup
    super
    @temporary = Dir.mktmpdir("stryker-launch-test-")
  end

  def teardown
    FileUtils.remove_entry(@temporary)
  end

  # Makes the run, and launches its process with `process`, with the run's
  # folder made inside `@temporary`, and raises what the launch raises. A
  # launch that signals is made while signals are deferred, as its callers
  # make it, and returns the watch the launch made by the time the signal
  # raises.
  def launched_with(process, expected, deferred: false)
    folder = Dir.method(:mktmpdir)
    in_temporary = -> (prefix) { folder.call(prefix, @temporary) }
    Dir.stub(:mktmpdir, in_temporary) do
      fresh = Stryker::Isolation::FreshRun.judged(sample_run(7, static: true)) { nil }
      launch = Stryker::Isolation::FreshLaunch.new("/cache", @temporary, process)

      watch = nil
      launching = -> { watch = launch.call(fresh, Stryker::TestRunners::Recipe.new("minitest")) }
      assert_raises(expected) { deferred ? Stryker::Isolation::Deferred.signals { launching.call } : launching.call }
      watch
    end
  end

  def run_folder
    File.join(@temporary, Dir.children(@temporary).first)
  end

  def test_a_launch_that_fails_leaves_no_folder
    launched_with(IsolationStandIns::RefusingProcess.new, Errno::ENOENT)

    assert_empty(Dir.children(@temporary))
  end

  def test_a_launch_that_fails_after_the_process_started_ends_the_process_before_it_deletes_the_folder
    process = StartedThenFailing.new(self, -> { run_folder }, error: ThreadError)
    launched_with(process, ThreadError)

    assert_equal([true, []], [process.folder_stood_at_kill, Dir.children(@temporary)])
    assert_raises(Errno::ECHILD) { Process.wait(process.pid) }
  end

  def test_an_interrupt_as_the_process_starts_waits_for_a_watch_that_ends_the_process_before_it_deletes_the_folder
    process = StartedThenFailing.new(self, -> { run_folder }, interrupted: true)
    launched_with(process, Interrupt, deferred: true).stop

    assert_equal([true, []], [process.folder_stood_at_kill, Dir.children(@temporary)])
    assert_raises(Errno::ECHILD) { Process.wait(process.pid) }
  end
end
