# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "stryker/config"
require "stryker/isolation"
require "tmpdir"

# What the fork adapter does in the orchestrator, against a stand-in parent:
# a Ruby process, on every system, that answers each run with scripted lines.
class ForkPerRunTest < Minitest::Test
  include IsolationStandIns

  parallelize_me!

  # Says it is ready, or that it failed, or nothing, as its argument says,
  # and then answers each run on standard input as its first test ID says.
  PARENT = <<~RUBY
    require "json"
    $stdout.sync = true
    say = ->(object) { puts(JSON.generate(object)) }
    sleep if ARGV.first == "silent"
    exit!(1) if ARGV.first == "gone"
    say.call(ARGV.first == "late" ? { error: "NameError: Minitest" } : { ready: true })
    $stdin.each_line do |line|
      run = JSON.parse(line)
      id = run.dig("mutant", "id")
      case run["test_ids"].first
      when "die" then exit!(1)
      when "stray" then say.call({ mutant: id + 100, forked: 1 })
      else
        say.call({ mutant: id, forked: Process.pid })
        say.call({ mutant: id, message: { ended: true } })
        say.call({ mutant: id, exited: { exit_status: 0, signal: nil, timed_out: false, duration_ms: 1.0, errors: "" } })
      end
    end
  RUBY
  private_constant(:PARENT)

  # Starts the stand-in parent in place of the real one, and keeps the folder
  # for the parent's output. With `interrupted`, the wait for the parent to
  # load raises Interrupt, as a signal that arrives then does.
  class Launch
    attr_reader :folder

    def initialize(test, argument = "ready", interrupted: false)
      @test = test
      @argument = argument
      @interrupted = interrupted
    end

    def call(_runner)
      input, commands = IO.pipe
      results, output = IO.pipe
      pid = @test.start_process(RbConfig.ruby, "-e", PARENT, @argument, in: input, out: output)
      [input, output].each(&:close)
      @folder = Dir.mktmpdir
      parent = Stryker::Isolation::ParentProcess.new(Stryker::Isolation::Child.new(pid), [commands, results], @folder)
      parent.define_singleton_method(:await_ready) { |*| raise(Interrupt) } if @interrupted
      parent
    end
  end
  private_constant(:Launch)

  def config(concurrency = 2)
    Stryker::Config.new(mutate: ["lib/**/*.rb"], test_runner: "minitest", concurrency:)
  end

  def started(launch = Launch.new(self), concurrency: 2)
    Stryker::Isolation::ForkPerRun.new("/cache", "/project", launch).tap { |isolation| isolation.start(config(concurrency)) }
  end

  def results_of(runs)
    isolation = started
    results = []
    isolation.run_all(runs) { |result| results << result }
    isolation.stop
    [results, isolation]
  end

  def test_the_adapter_yields_each_result_as_the_parent_says_how_each_child_ended
    results, = results_of([sample_run(1), sample_run(2), sample_run(3)])

    assert_equal(
      [1, 2, 3],
      results.map { |result| result.mutant.id }
      .sort!
    )
    assert_equal(["RuntimeError"] * 3, results.map(&:status))
  end

  def test_a_second_stop_does_nothing
    _, isolation = results_of([sample_run(1)])

    assert_nil(isolation.stop)
  end

  def test_the_adapter_refuses_a_static_mutant_before_it_runs_any
    isolation = started
    error = assert_raises(ArgumentError) { isolation.run_all([sample_run(1), sample_run(2, static: true)]) { nil } }

    assert_includes(error.message, "Mutant 2 is static")
  ensure
    isolation&.stop
  end

  def test_the_adapter_raises_when_the_parent_ends_before_it_is_ready
    error = assert_raises(Stryker::Isolation::Error) { started(Launch.new(self, "late")) }

    assert_includes(error.message, "NameError: Minitest")
  end

  def test_the_adapter_raises_when_the_parent_ends_or_writes_about_another_mutant
    [%w[die ended], %w[stray 101]].each do |test_id, message|
      isolation = started(concurrency: 1)
      error = assert_raises(Stryker::Isolation::Error) { isolation.run_all([sample_run(1, test_ids: [test_id])]) { nil } }

      assert_includes(error.message, message)
    end
  end

  def test_the_adapter_raises_when_the_parent_ends_before_it_says_anything
    error = assert_raises(Stryker::Isolation::Error) { started(Launch.new(self, "gone")) }

    assert_includes(error.message, "ended before it loaded the tests, and said nothing.")
  end

  def test_a_parent_that_loads_no_tests_in_time_is_stopped_with_an_error_that_names_the_limit
    parent = Launch.new(self, "silent").call("minitest")
    error = assert_raises(Stryker::Isolation::Error) { parent.await_ready(0.5) }

    assert_includes(error.message, "0.5 seconds")
    assert_includes(error.message, "test/test_helper.rb")
  end

  def test_an_interrupt_while_the_parent_loads_ends_the_parent_and_deletes_its_output
    launch = Launch.new(self, "silent", interrupted: true)

    assert_raises(Interrupt) { Stryker::Isolation::ForkPerRun.new("/cache", "/project", launch).start(config) }
    refute(Dir.exist?(launch.folder))
  end

  def test_the_adapter_needs_starting_first
    assert_raises(Stryker::Isolation::Error) { Stryker::Isolation::ForkPerRun.new("/cache").run_all([sample_run]) { nil } }
  end
end
