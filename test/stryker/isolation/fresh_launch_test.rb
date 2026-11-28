# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "minitest/mock"
require "rbconfig"
require "stryker/isolation"
require "stryker/test_runners/recipe"
require "tmpdir"

# What the launch of a fresh process leaves behind when something fails, once
# the run is stopped, as the set of runs stops it, with a stand-in for
# Process, on every system.
class FreshLaunchTest < Minitest::Test
  include IsolationStandIns

  # Starts a process that waits, in place of the project's, with an
  # Interrupt for the launching thread as `spawn` returns, as Ctrl-C makes
  # one. It notes whether the run's folder still stood when the process was
  # killed, and the pipe it was given as standard output.
  class Interrupted
    attr_reader :pid, :folder_stood_at_kill, :out

    def initialize(test, folder)
      @test = test
      @folder = folder
    end

    def spawn(*, options)
      @out = options[:out]
      @pid = @test.start_process(RbConfig.ruby, "-e", "sleep")
      Thread.current.raise(Interrupt)
      @pid
    end

    def kill(*)
      @folder_stood_at_kill = Dir.exist?(@folder.call)
      Process.kill(*)
    end

    def wait2(*)
      Process.wait2(*)
    end
  end
  private_constant(:Interrupted)

  def setup
    super
    @temporary = Dir.mktmpdir("stryker-launch-test-")
  end

  def teardown
    FileUtils.remove_entry(@temporary)
  end

  # Makes the run, with its folder inside `@temporary`, launches its process
  # with `process`, checks that the launch raises `expected`, and stops the
  # run.
  def launched_with(process, expected)
    folder = Dir.method(:mktmpdir)
    in_temporary = -> (prefix) { folder.call(prefix, @temporary) }
    fresh = Dir.stub(:mktmpdir, in_temporary) do
      Stryker::Isolation::FreshRun.judged(sample_run(7, static: true), Stryker::Isolation::FreshFolder.made) { nil }
    end
    launch = Stryker::Isolation::FreshLaunch.new("/cache", @temporary, process)

    assert_raises(expected) { fresh.launch(launch, Stryker::TestRunners::Recipe.new("minitest")) }
    fresh.stop
  end

  def run_folder
    File.join(@temporary, Dir.children(@temporary).first)
  end

  # Starts a process that waits, in place of the project's, and notes its
  # ID.
  class Waiting
    attr_reader :pid

    def initialize(test)
      @test = test
    end

    def spawn(*)
      @pid = @test.start_process(RbConfig.ruby, "-e", "sleep")
    end

    def kill(*)
      Process.kill(*)
    end

    def wait2(*)
      Process.wait2(*)
    end
  end
  private_constant(:Waiting)

  # A thread made while signals are deferred keeps them deferred, and
  # Ruby waits for its threads as it exits, so a waiter made in the launch
  # would keep the program running past a second Ctrl-C (#130).
  def test_no_thread_waits_on_a_launched_process
    process = Waiting.new(self)
    fresh = Stryker::Isolation::FreshRun.judged(sample_run(7, static: true), Stryker::Isolation::FreshFolder.made) { nil }
    fresh.launch(Stryker::Isolation::FreshLaunch.new("/cache", @temporary, process), Stryker::TestRunners::Recipe.new("minitest"))

    assert_empty(Thread.list.grep(Process::Waiter).select { |waiter| waiter.pid == process.pid })
  ensure
    fresh&.stop
  end

  def test_a_launch_that_fails_leaves_no_folder
    launched_with(IsolationStandIns::RefusingProcess.new, Errno::ENOENT)

    assert_empty(Dir.children(@temporary))
  end

  def test_an_interrupt_as_the_process_starts_waits_for_the_run_to_hold_it_and_stop_ends_it_before_it_deletes_the_folder
    process = Interrupted.new(self, -> { run_folder })
    launched_with(process, Interrupt)

    assert_equal([true, true, []], [process.folder_stood_at_kill, process.out.closed?, Dir.children(@temporary)])
    assert_raises(Errno::ECHILD) { Process.wait(process.pid) }
  end
end
