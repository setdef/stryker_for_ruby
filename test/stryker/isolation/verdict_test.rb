# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "stryker/isolation/ending"
require "stryker/isolation/messages"
require "stryker/isolation/verdict"

# How a run's messages and its process's ending become its status.
class VerdictTest < Minitest::Test
  include IsolationStandIns

  KINDS = { Stryker::Test => "started", Stryker::TestResult => "finished" }.freeze
  private_constant(:KINDS)

  def ending(exit_status: 0, signal: nil, timed_out: false)
    Stryker::Isolation::Ending.new(exit_status:, signal:, timed_out:, duration_ms: 12.5, errors: "")
  end

  def killed_by_signal(timed_out: false)
    ending(exit_status: nil, signal: "KILL", timed_out:)
  end

  # The messages of +values+: a test that started, a test's result, or
  # :ended.
  def messages(*values)
    objects = values.map do |value|
      (value == :ended) ? { ended: true } : { KINDS[value.class] => value.as_json }
    end
    Stryker::Isolation::Messages.new(objects.map { |object| JSON.parse(JSON.generate(object)) })
  end

  def judged(said, end_of_process, run = sample_run)
    Stryker::Isolation::Verdict.new(run, said, end_of_process).result
  end

  def test_a_failed_test_kills_the_mutant_whatever_the_process_did_after_it
    failed = sample_result("failed", failure_message: "Expected 90")
    [ending, ending(exit_status: 1), killed_by_signal(timed_out: true)].each do |end_of_process|
      result = judged(messages(sample_test, failed), end_of_process)

      assert_equal(
        ["Killed", "Expected 90", ["SampleTest#test_value"], 1],
        [result.status, result.status_reason, result.killed_by, result.tests_completed]
      )
    end
  end

  def test_a_run_past_its_time_limit_with_no_failure_times_out
    result = judged(messages(sample_test), killed_by_signal(timed_out: true), sample_run(timeout_ms: 1500))

    assert_equal(
      ["Timeout", "Timeout of 1500 ms exceeded.", []],
      [result.status, result.status_reason, result.killed_by]
    )
  end

  def test_a_run_that_ended_with_every_test_passed_and_a_clean_exit_survives
    result = judged(messages(sample_test, sample_result("passed"), :ended), ending)

    assert_equal(
      ["Survived", nil, 1, 12.5],
      [result.status, result.status_reason, result.tests_completed, result.duration_ms]
    )
    assert_equal(["SampleTest#test_value"], result.covered_by)
  end

  def test_a_run_that_falls_short_of_surviving_is_a_runtime_error
    passed = sample_result("passed")
    two = sample_run(test_ids: %w[SampleTest#test_value SampleTest#test_other])
    statuses = [
      judged(messages(passed), ending),
      judged(messages(passed, :ended), ending(exit_status: 1)),
      judged(messages(passed, :ended), ending, two),
].map(&:status)

    assert_equal(["RuntimeError"] * 3, statuses)
  end

  def test_a_runtime_error_gives_the_error_the_process_wrote
    said = Stryker::Isolation::Messages.new([JSON.parse(JSON.generate({ error: "SystemExit: exit" }))])

    assert_equal("SystemExit: exit", judged(said, ending(exit_status: 1)).status_reason)
  end

  def test_a_runtime_error_otherwise_says_how_the_process_ended_and_during_which_test
    signaled = judged(messages(sample_test), ending(exit_status: nil, signal: "SEGV")).status_reason
    exited = judged(messages, ending(exit_status: 3)).status_reason

    assert_equal(
      "The run's process was ended by signal SEGV after 0 of its 1 tests finished, " \
        "while SampleTest#test_value ran.",
      signaled
    )
    assert_equal("The run's process exited with status 3 after 0 of its 1 tests finished.", exited)
  end

  def test_a_runtime_error_ends_with_the_end_of_standard_error
    said = Stryker::Isolation::Messages.new([JSON.parse(JSON.generate({ error: "SystemExit: exit" }))])
    stderr = ending(exit_status: 1).with(errors: "warning: one\n[BUG] two\n")

    assert_equal("SystemExit: exit\nwarning: one\n[BUG] two", judged(said, stderr).status_reason)
  end

  def test_a_result_is_covered_by_the_tests_its_run_lists_as_covering_it
    said = messages(sample_test, sample_result("passed"), :ended)
    runtime = judged(said, ending, sample_run(covered_by: ["SampleTest#test_value"]))
    static = judged(said, ending, sample_run(static: true, covered_by: ["SampleTest#test_other"]))

    assert_equal(
      [["SampleTest#test_value"], false, ["SampleTest#test_other"], true],
      [runtime.covered_by, runtime.static, static.covered_by, static.static]
    )
  end
end
