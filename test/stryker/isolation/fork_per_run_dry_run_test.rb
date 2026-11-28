# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "stryker/config"
require "stryker/isolation"
require "tmpdir"

# What the fork adapter does with the dry run in the orchestrator, against a
# stand-in parent: a Ruby process, on every system, that answers the dry run
# with scripted lines.
class ForkPerRunDryRunTest < Minitest::Test
  include IsolationStandIns

  parallelize_me!

  # Says it is ready, and then answers a dry run with a limit of one minute
  # with a test that passed, and any other dry run with a test that failed.
  PARENT = <<~RUBY
    require "json"
    $stdout.sync = true
    say = ->(object) { puts(JSON.generate({ dry_run: true, **object })) }
    puts(JSON.generate({ ready: true }))
    test = { id: "SampleTest#test_value", name: "test_value", file: nil, location: nil }
    $stdin.each_line do |line|
      status = JSON.parse(line).dig("dry_run", "timeout_ms") == 60_000 ? "passed" : "failed"
      result = { test:, status:, failure_message: status == "failed" ? "Expected 90" : nil, duration_ms: 1.0 }
      found = { results: [result], buckets: {}, static_bucket: [1], files_loaded_in_tests: [], duration_ms: 1.0 }
      say.call({ forked: Process.pid })
      [{ started: test }, { finished: result }, { result: found }, { ended: true }].each { |message| say.call({ message: }) }
      say.call({ exited: { exit_status: 0, signal: nil, timed_out: false, duration_ms: 1.0, errors: "" } })
    end
  RUBY
  private_constant(:PARENT)

  # Starts the stand-in parent in place of the real one.
  class Launch
    def initialize(test)
      @test = test
    end

    def call(_runner)
      input, commands = IO.pipe
      results, output = IO.pipe
      pid = @test.start_process(RbConfig.ruby, "-e", PARENT, in: input, out: output)
      [input, output].each(&:close)
      pipes = Stryker::Isolation::ParentPipes.new(commands:, results:)
      Stryker::Isolation::ParentProcess.new(Stryker::Isolation::Child.new(pid), pipes, Dir.mktmpdir)
    end
  end
  private_constant(:Launch)

  def config(minutes)
    Stryker::Config.new(mutate: ["lib/**/*.rb"], test_runner: "minitest", dry_run_timeout_minutes: minutes)
  end

  def started
    Stryker::Isolation::ForkPerRun.new("/cache", "/project", Launch.new(self)).tap { |isolation| isolation.start(config(5)) }
  end

  def test_the_dry_run_gives_the_parent_its_limit_and_returns_what_it_found
    isolation = started
    found = isolation.dry_run(config(1))

    assert_equal([[1], ["passed"]], [found.static_bucket, found.results.map(&:status)])
  ensure
    isolation&.stop
  end

  def test_a_dry_run_that_failed_raises_and_stops_the_parent
    isolation = started
    error = assert_raises(Stryker::Isolation::DryRunError) { isolation.dry_run(config(2)) }

    assert_includes(error.message, "SampleTest#test_value failed")
    assert_raises(Stryker::Isolation::Error) { isolation.run_all([sample_run]) { nil } }
  end

  def test_the_dry_run_needs_starting_first
    assert_raises(Stryker::Isolation::Error) { Stryker::Isolation::ForkPerRun.new("/cache").dry_run(config(5)) }
  end
end
