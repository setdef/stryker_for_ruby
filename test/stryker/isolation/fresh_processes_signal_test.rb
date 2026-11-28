# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "minitest/mock"
require "rbconfig"
require "stryker/config"
require "stryker/isolation/fresh_launch"
require "stryker/isolation/fresh_processes"
require "tmpdir"

# What a signal leaves behind when it arrives as a fresh process starts: the
# process ended and the run's folder deleted by the time the adapter returns,
# wherever the signal lands. The signal is a `Thread#raise`, as a signal's
# handler makes it, at the points a test names.
class FreshProcessesSignalTest < Minitest::Test
  include IsolationStandIns

  # Starts a process that waits, in place of the project's, and notes its ID.
  class WaitingProcess
    attr_reader :pid

    def initialize(test)
      @test = test
    end

    def spawn(*)
      @pid = @test.start_process(RbConfig.ruby, "-e", "sleep")
    end

    def detach(pid)
      Process.detach(pid)
    end

    def kill(*)
      Process.kill(*)
    end

    def wait(pid)
      Process.wait(pid)
    end
  end
  private_constant(:WaitingProcess)

  # A launch that signals the launching thread as the real launch returns,
  # and so before the watch that it returns, if it returns one, is in the
  # set that waits on it.
  class SignalledLaunch
    def initialize(launch)
      @launch = launch
    end

    def call(*)
      @launch.call(*).tap { Thread.current.raise(Interrupt) }
    end
  end
  private_constant(:SignalledLaunch)

  def setup
    @temporary = Dir.mktmpdir("stryker-signal-test-")
    @process = WaitingProcess.new(self)
  end

  def teardown
    FileUtils.remove_entry(@temporary)
  end

  def config
    Stryker::Config.new(mutate: ["lib/**/*.rb"], test_runner: "minitest", concurrency: 1)
  end

  # The adapter, with each run's folder made inside `@temporary`, which
  # starts its processes in place of the project's.
  def isolation(launch = Stryker::Isolation::FreshLaunch.new("/cache", @temporary, @process))
    Stryker::Isolation::FreshProcesses.new("/cache", @temporary, launch).tap { |adapter| adapter.start(config) }
  end

  def in_temporary(&)
    folder = Dir.method(:mktmpdir)
    Dir.stub(:mktmpdir, -> (prefix) { folder.call(prefix, @temporary) }, &)
  end

  # As `in_temporary`, with a signal for the thread as each folder is made,
  # before whoever asked for it holds it.
  def in_signalled_temporary(&)
    folder = Dir.method(:mktmpdir)
    signalled = -> (prefix) { folder.call(prefix, @temporary).tap { Thread.current.raise(Interrupt) } }
    Dir.stub(:mktmpdir, signalled, &)
  end

  # The folders left, and whether every process started has ended and been
  # reaped, without waiting for any.
  def leftovers
    [Dir.children(@temporary), [@process.pid].compact.all? { |pid| ended?(pid) }]
  end

  # Whether the process has ended and been reaped, without waiting for it.
  def ended?(pid)
    Process.wait(pid, Process::WNOHANG)
    false
  rescue Errno::ECHILD
    true
  end

  def test_a_signal_after_the_launch_returns_ends_the_process_and_deletes_the_folder
    adapter = isolation(SignalledLaunch.new(Stryker::Isolation::FreshLaunch.new("/cache", @temporary, @process)))

    in_temporary { assert_raises(Interrupt) { adapter.run_all([sample_run(7, static: true)]) { nil } } }
    assert_equal([[], true], leftovers)
  end

  def test_a_signal_after_the_dry_runs_launch_returns_ends_the_process_and_deletes_the_folder
    adapter = isolation(SignalledLaunch.new(Stryker::Isolation::FreshLaunch.new("/cache", @temporary, @process)))

    in_temporary { assert_raises(Interrupt) { adapter.dry_run(config) } }
    assert_equal([[], true], leftovers)
  end

  def test_a_signal_as_a_runs_folder_is_made_leaves_no_folder_and_no_process
    in_signalled_temporary { assert_raises(Interrupt) { isolation.run_all([sample_run(7, static: true)]) { nil } } }

    assert_equal([[], true], leftovers)
  end

  def test_a_signal_as_the_dry_runs_folder_is_made_leaves_no_folder_and_no_process
    in_signalled_temporary { assert_raises(Interrupt) { isolation.dry_run(config) } }

    assert_equal([[], true], leftovers)
  end
end
