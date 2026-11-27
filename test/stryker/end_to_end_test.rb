# frozen_string_literal: true

require_relative("../report_schema")
require_relative("../support/sample_projects")
require_relative("../test_helper")
require "open3"
require "tmpdir"

# Runs `stryker run` as a user runs it, in a fresh process, on the sample
# project in test/fixtures/sample_project, which is built so that its run
# holds a mutant of each status that a run can give it. Where the system has
# no fork, a run isn't built, and each test checks that the command says so
# instead.
class EndToEndTest < Minitest::Test
  include ReportSchema
  include SampleProjects

  parallelize_me!

  SAMPLE = "sample_project"
  FORKS = Process.respond_to?(:fork)
  # Each mutant that the sample is built to give, by its file, line, mutator,
  # and replacement, with its status and whether it is static. The run holds
  # other mutants as well, whose statuses the test doesn't check.
  BUILT = {
    ["lib/shop/price.rb", 9, "ArithmeticOperator", "price - tax"] => ["Killed", false],
    ["lib/shop/price.rb", 13, "EqualityOperator", "age > 65"] => ["Survived", false],
    ["lib/shop/refund.rb", 7, "ArithmeticOperator", "price / 2"] => ["NoCoverage", false],
    ["lib/shop/countdown.rb", 8, "AssignmentOperator", "count += 1"] => ["Timeout", false],
    ["lib/shop/greeting.rb", 6, "StringLiteral", '""'] => ["Killed", true],
  }.freeze
  REFUSED = "A run on Windows isn't built yet: Stryker (for Ruby) runs each runtime mutant in a process " \
    "forked from one that loaded the project, and Windows has no fork.\n"
  private_constant(:SAMPLE, :FORKS, :BUILT, :REFUSED)

  # Runs the command in a copy of the sample, with the flags, and with
  # `TMPDIR` set to `temporary`.
  def stryker(*flags, temporary: Dir.tmpdir)
    run_in_copy(SAMPLE, *flags, temporary:)
  end

  # The status and staticness of each mutant of `report` that the sample is
  # built to give.
  def built_mutants(report)
    found = report["files"].flat_map { |file, entry| entry["mutants"].map { |mutant| keyed(file, mutant) } }
    found.to_h.slice(*BUILT.keys)
  end

  def keyed(file, mutant)
    key = [file, mutant.dig("location", "start", "line"), mutant["mutatorName"], mutant["replacement"]]
    [key, [mutant["status"], mutant["static"]]]
  end

  def assert_refused(outcome)
    assert_equal([2, "", REFUSED, nil], outcome.to_h.values)
  end

  def assert_reported(outcome)
    report = outcome.report

    assert_valid_report(report)
    assert_equal([0, BUILT, true], [outcome.status, built_mutants(report), outcome.out.include?("All files")])
  end

  def test_a_run_reports_each_status_the_sample_is_built_to_give_and_passes_above_the_break_threshold
    outcome = stryker("--thresholds.break", "50")

    FORKS ? assert_reported(outcome) : assert_refused(outcome)
  end

  def test_a_run_whose_score_is_below_the_break_threshold_exits_with_status_one
    outcome = stryker("--thresholds.break", "100")

    FORKS ? assert_equal([1, ""], [outcome.status, outcome.err]) : assert_refused(outcome)
  end

  def test_a_terminate_signal_ends_the_run_and_leaves_no_cache_and_no_fork_parent
    Dir.mktmpdir("stryker-end-to-end-temporary-") do |temporary|
      FORKS ? assert_terminated(temporary) : assert_refused(stryker(temporary:))
    end
  end

  def assert_terminated(temporary)
    status, err = terminated(temporary)

    assert_equal([143, "Stopped by TERM.\n", []], [status, err, Dir.children(temporary)])
  end

  # Starts the command in a copy of the sample, sends it TERM once the fork
  # parent has started, and gives how it ended.
  private def terminated(temporary)
    in_copy(SAMPLE) do |root|
      Open3.popen3({ "TMPDIR" => temporary }, *COMMAND, chdir: root) do |stdin, _out, err, waiter|
        stdin.close
        sleep(0.01) until Dir.glob("stryker-fork-*", base: temporary).any? || !waiter.alive?
        Process.kill("TERM", waiter.pid)
        [waiter.value.exitstatus, err.read]
      end
    end
  end
end
