# frozen_string_literal: true

require_relative("../test_helper")
require "rbconfig"
require "stryker/instrumenter"
require "tmpdir"

# Starts parse workers that stand in for the real one, and finds which of
# the processes they started are still running.
module ParseWorkers
  LIB = File.expand_path("../../lib", __dir__)

  # Each stand-in writes a file named for its process ID in the folder that
  # ARGV[0] names, and waits until ARGV[1] of them have, so that a test knows
  # every process that ever started.
  RECORD = <<~RUBY
    $stdout.sync = true
    File.write(File.join(ARGV[0], Process.pid.to_s), "")
    sleep(0.01) until Dir.children(ARGV[0]).size >= Integer(ARGV[1])
  RUBY
  # Reads the source, which a worker doesn't answer, and then a plain mutant.
  TAKE = "$stdin.gets; $stdin.gets"
  # Behaviors of a stand-in after it starts.
  BEHAVIORS = {
    real: 'require "stryker/instrumenter/parse_worker"; Stryker::Instrumenter::ParseWorker.serve',
    ends_at_once: "exit 3",
    dies_after_taking_the_job: "#{TAKE}; exit 2",
    dies_with_a_message: "#{TAKE}; warn('boom'); exit 2",
    answers_with_text: "#{TAKE}; puts('oops'); sleep",
    answers_with_json_that_is_no_verdict: "#{TAKE}; puts('{\"id\":999}'); sleep",
  }.freeze
  private_constant(:BEHAVIORS, :LIB, :RECORD, :TAKE)

  # The command that starts a stand-in with the +behavior+, which records
  # itself in +folder+. +count+ is how many stand-ins the test starts.
  def worker_command(behavior, folder, count)
    [RbConfig.ruby, "-I", LIB, "-e", "#{RECORD}#{BEHAVIORS[behavior]}", folder, count.to_s]
  end

  # The IDs of the processes that the stand-ins in +folder+ started.
  def started(folder)
    Dir.children(folder).map { |name| Integer(name, 10) }
  end

  # +count+ plain mutants of "x = 1", numbered from 1: every second one
  # replaces the 1 by "y", which parses, and the others by "y +", which
  # doesn't.
  def plains(count)
    Array.new(count) do |index|
      replacement = index.odd? ? "y +" : "y"
      mutant = Stryker::Mutant.new(
        id: index + 1, file: "lib/x.rb", mutator_name: "Case", start_offset: 4, end_offset: 5, replacement:
      )
      node = Stryker::Instrumenter::Span.new(start_offset: 4, end_offset: 5)
      Stryker::Instrumenter::PlainMutant.new(mutant:, bodies: [], node:)
    end
  end

  # Runs the block with a folder where stand-in workers record themselves,
  # and checks that none of them is running when the block ends, however
  # it ends.
  def with_workers
    Dir.mktmpdir do |folder|
      yield(folder)
    ensure
      assert_none_running(started(folder))
    end
  end

  def running?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  end

  def assert_none_running(pids)
    assert_empty(pids.select { |pid| running?(pid) }, "Processes left running.")
  end
end
