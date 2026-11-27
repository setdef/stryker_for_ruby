# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "stryker/isolation/fork_parent"
require "tmpdir"

# The loop of the parent that forks, in this process, with a stand-in for the
# forking that starts a real Ruby process for each run, so the loop runs on
# every system.
class ForkParentTest < Minitest::Test
  include IsolationStandIns

  parallelize_me!

  # Starts, for each run, the process whose script the run's first test ID
  # holds.
  class Scripts
    def initialize(test)
      @test = test
    end

    def start(run, _work)
      @test.scripted(run.test_ids.first)
    end

    def errors(_run)
      "the child's standard error\n"
    end
  end
  private_constant(:Scripts)

  # A test runner that loads no test, or raises when it loads.
  class Runner
    def initialize(error = nil)
      @error = error
    end

    def load_tests
      raise(@error) if @error

      []
    end
  end
  private_constant(:Runner)

  # Runs the block and records the code it would end the process with.
  class Finisher
    attr_reader :code

    def call(report, &)
      @code = report.conclude(&)
    end
  end
  private_constant(:Finisher)

  # Gives the parent +runs+ on its standard input from a process of its own,
  # which keeps that input open until the parent has written +lines+ lines.
  # Returns what the parent wrote, and the code it would end with.
  def served(runs, lines: 0, runner: Runner.new)
    Dir.mktmpdir do |folder|
      path = File.join(folder, "results")
      File.write(path, "")
      input = feeder(runs, path, lines)
      finisher = Finisher.new
      File.open(path, "w") { |results| parent(runner, results).call(input, finisher) }
      input.close
      [File.foreach(path).map { |line| JSON.parse(line, symbolize_names: true) }, finisher.code]
    end
  end

  def feeder(runs, path, lines)
    commands = runs.map { |run| "#{run.to_json}\n" }
      .join
    # Once the test has ended, the file is gone, and the feeder ends too.
    wait = "sleep(0.01) until !File.exist?(#{path.inspect}) || File.readlines(#{path.inspect}).size >= #{lines}"
    pid, input = scripted("$stdout.sync = true; print(#{commands.inspect}); #{wait}")
    Process.detach(pid)
    input
  end

  def parent(runner, results)
    relay = Stryker::Isolation::Relay.new(results)
    Stryker::Isolation::ForkParent.new(runner, Stryker::Isolation::Children.new(Scripts.new(self), relay), relay)
  end

  def script_run(script, timeout_ms: 30_000)
    sample_run(7, test_ids: [script], timeout_ms:)
  end

  def test_the_parent_says_it_is_ready_and_which_child_runs_each_run
    lines, = served([script_run("exit!(0)")], lines: 3)

    assert_equal({ ready: true }, lines.first)
    assert_equal(7, lines.dig(1, :mutant))
    assert_kind_of(Integer, lines.dig(1, :forked))
  end

  def test_the_parent_relays_each_line_a_child_writes_and_how_it_ended
    lines, code = served([script_run("$stdout.sync = true; puts('{\"ended\":true}'); exit!(3)")], lines: 4)

    assert_equal({ mutant: 7, message: { ended: true } }, lines[2])
    assert_equal(
      [3, false, "the child's standard error\n"],
      lines.dig(3, :exited).values_at(:exit_status, :timed_out, :errors)
    )
    assert_equal([{ ended: true }, 0], [lines.last, code])
  end

  def test_the_parent_kills_a_child_past_its_time_limit
    # The limit starts with the run's first test.
    lines, = served([script_run("$stdout.sync = true; puts('{\"started\":{}}'); sleep", timeout_ms: 300)], lines: 4)

    assert(lines.dig(3, :exited, :timed_out))
  end

  def test_the_parent_ends_a_child_still_running_when_the_runs_stop_coming
    lines, code = served([script_run("sleep")])

    assert_equal([[{ ended: true }], 0], [lines.drop(2), code])
  end

  def test_a_parent_that_cannot_load_the_tests_says_why_in_place_of_ready
    lines, code = served([], runner: Runner.new(NameError.new("uninitialized constant Minitest")))

    assert_equal([[{ error: "NameError: uninitialized constant Minitest" }], 1], [lines, code])
  end

  def test_the_parent_gives_its_children_nothing_on_standard_input
    input, commands = IO.pipe
    commands.close
    File.open(File::NULL, "w") { |null| parent(Runner.new, null).call(input, Finisher.new) }

    refute_predicate(input.stat, :pipe?)
  ensure
    input&.close
  end
end
