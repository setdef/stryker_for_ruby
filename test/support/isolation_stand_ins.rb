# frozen_string_literal: true

require_relative("../test_helper")
require "rbconfig"
require "stryker/isolation/fresh_run"
require "stryker/isolation/process_group"
require "stryker/mutant"
require "stryker/mutant_run"
require "stryker/test"
require "stryker/test_result"

# Stand-ins for what the isolation code drives, so its tests run on every
# system: a record of the calls it makes to Process, and real processes that
# write scripted lines, in place of forked children.
module IsolationStandIns
  # Records each call it gets, and answers fork and spawn with a made-up
  # process ID, without running anything.
  class FakeProcess
    PID = 4242
    public_constant(:PID)

    attr_reader :calls

    def initialize(kill_error: nil, setpgid_error: nil, pgrp: nil)
      @calls = []
      @kill_error = kill_error
      @setpgid_error = setpgid_error
      @pgrp = pgrp
    end

    # Takes the child's block, and never runs it.
    def fork(&)
      @calls << [:fork]
      PID
    end

    def spawn(*arguments)
      @calls << [:spawn, *arguments]
      PID
    end

    def setpgid(*arguments)
      @calls << [:setpgid, *arguments]
      raise(@setpgid_error) if @setpgid_error
    end

    # The process ID of the process that asks, as a forked child sees it.
    def pid
      PID
    end

    # The process group of the process that asks: its own, unless +pgrp+
    # said otherwise.
    def getpgrp
      @pgrp || PID
    end

    def kill(*arguments)
      @calls << [:kill, *arguments]
      raise(@kill_error) if @kill_error
    end

    def exit!(code)
      @calls << [:exit!, code]
    end

    def detach(pid)
      @calls << [:detach, pid]
      Waiter.new
    end
  end

  # Spawns nothing, and raises the error that a missing project root makes.
  class RefusingProcess
    def spawn(*)
      raise(Errno::ENOENT, "the project's root")
    end
  end

  # The waiter of a process that has already ended.
  class Waiter
    def join(_seconds = nil)
      self
    end

    def alive?
      false
    end

    def value
      nil
    end
  end

  # A launch that starts nothing and hands the run the process +child+ and
  # the time limit +timer+, as if it had started the process: where each
  # test of a fresh run whose process runs starts from.
  class HeldLaunch
    # The stage of a run whose process the launch "started".
    class Held < Stryker::Isolation::FreshRun::Stage
      def initialize(folder, child, timer)
        super()
        @folder = folder
        @child = child
        @timer = timer
      end

      def hold(_timeout_ms)
        Stryker::Isolation::FreshRun::Running.new(@folder, @child, @timer)
      end
    end

    def initialize(child, timer)
      @child = child
      @timer = timer
    end

    def call(folder, _run, _recipe)
      Held.new(folder, @child, @timer)
    end
  end

  # The processes that one test started, which end when the test ends,
  # however it ends: a stand-in that waits for the code under test to end it
  # would otherwise stay running when an assertion fails first.
  class Started
    def initialize
      @pids = Queue.new
    end

    # Starts the process that +arguments+ and +options+ describe, in a group
    # of its own where the system has groups.
    def spawn(*arguments, **options)
      Process.spawn(*arguments, **options, **Stryker::Isolation::ProcessGroup::SYSTEM.spawn_options)
        .tap { |pid| @pids << pid }
    end

    # Ends each process that is still running, and reaps it. What an ended
    # process left running in its group ends too.
    def end_all
      @pids.size.times { end_one(@pids.pop) }
    end

    private def end_one(pid)
      return Stryker::Isolation::ProcessGroup.kill_rest(pid) if Process.wait(pid, Process::WNOHANG)

      Stryker::Isolation::ProcessGroup.kill(pid)
      Process.wait(pid)
    rescue Errno::ECHILD
      Stryker::Isolation::ProcessGroup.kill_rest(pid)
    end
  end

  def before_setup
    super
    @started = Started.new
  end

  def after_teardown
    @started.end_all
    super
  end

  # Starts a process that ends with the test, in a group of its own where the
  # system has groups.
  def start_process(*, **)
    @started.spawn(*, **)
  end

  # Ends a process that a stand-in started, and that the test didn't.
  def end_process(pid)
    Process.kill(:KILL, pid)
  rescue Errno::ESRCH, Errno::EPERM
    nil
  end

  # A Ruby process that runs +script+, with its standard output on a new pipe.
  # Returns its process ID and the pipe's read end.
  def scripted(script)
    reader, writer = IO.pipe
    # Binary, because Ruby on Windows writes each LF to a pipe as CRLF.
    pid = start_process(RbConfig.ruby, "-e", "$stdout.binmode; #{script}", out: writer)
    writer.close
    [pid, reader]
  end

  # A fresh run of mutant 7's static run, in +folder+, whose process is
  # +child+, with the time limit +timer+, and the landing that the block
  # gives.
  def running_fresh(folder, child, timer, &landing)
    landing ||= -> (_messages, _ending) {}
    Stryker::Isolation::FreshRun.new(sample_run(7, static: true), folder, &landing).tap do |fresh|
      fresh.launch(HeldLaunch.new(child, timer), nil)
    end
  end

  def sample_test(name = "test_value")
    Stryker::Test.new(id: "SampleTest##{name}", name:, file: "test/sample_test.rb", location: nil)
  end

  def sample_result(status, name = "test_value", failure_message: nil)
    Stryker::TestResult.new(test: sample_test(name), status:, failure_message:, duration_ms: 0.5)
  end

  def sample_run(id = 7, static: false, test_ids: ["SampleTest#test_value"], covered_by: test_ids, timeout_ms: 5000)
    mutant = Stryker::Mutant.new(
      id:, file: "lib/sample.rb", mutator_name: "BooleanLiteral", start_offset: 0, end_offset: 4, replacement: "false"
    )
    Stryker::MutantRun.new(mutant:, static:, test_ids:, covered_by:, timeout_ms:)
  end

  # The process ID of a process that has ended and been reaped.
  def ended_pid
    pid = start_process(RbConfig.ruby, "-e", "nil")
    Process.wait(pid)
    pid
  end

  # The process ID of a process that ends at once, and that nothing has
  # reaped yet.
  def ended_pid_unreaped
    start_process(RbConfig.ruby, "-e", "nil")
  end

  # Each line on +io+ until it closes, parsed as JSON.
  def json_lines(io)
    io.each_line.map { |line| JSON.parse(line) }
  end
end
