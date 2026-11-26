# frozen_string_literal: true

require_relative("../test_helper")
require "rbconfig"
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

    def initialize(kill_error: nil)
      @calls = []
      @kill_error = kill_error
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

  # A Ruby process that runs +script+, with its standard output on a new pipe.
  # Returns its process ID and the pipe's read end.
  def scripted(script)
    reader, writer = IO.pipe
    # Binary, because Ruby on Windows writes each LF to a pipe as CRLF.
    pid = Process.spawn(
      RbConfig.ruby, "-e", "$stdout.binmode; #{script}", out: writer, **Stryker::Isolation::ProcessGroup::SYSTEM.spawn_options
    )
    writer.close
    [pid, reader]
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
    pid = Process.spawn(RbConfig.ruby, "-e", "nil")
    Process.wait(pid)
    pid
  end

  # The process ID of a process that ends at once, and that nothing has
  # reaped yet.
  def ended_pid_unreaped
    Process.spawn(RbConfig.ruby, "-e", "nil")
  end

  # Each line on +io+ until it closes, parsed as JSON.
  def json_lines(io)
    io.each_line.map { |line| JSON.parse(line) }
  end
end
