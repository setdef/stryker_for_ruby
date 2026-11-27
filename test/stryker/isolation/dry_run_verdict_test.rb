# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "stryker/dry_run_result"
require "stryker/isolation/dry_run"
require "stryker/isolation/dry_run_verdict"
require "stryker/isolation/ending"
require "stryker/isolation/messages"

# How the dry run's messages and its process's ending become what the dry run
# found, or the error that stops the run.
class DryRunVerdictTest < Minitest::Test
  include IsolationStandIns

  def ending(exit_status: 0, timed_out: false, errors: "")
    Stryker::Isolation::Ending.new(exit_status:, signal: nil, timed_out:, duration_ms: 12.5, errors:)
  end

  def found(results = [sample_result("passed")])
    buckets = { sample_test.id => [3] }
    Stryker::DryRunResult.new(results:, buckets:, static_bucket: [1], files_loaded_in_tests: [], duration_ms: 0.5)
  end

  # Each object in +objects+, a Hash of one message, as the parent relays it.
  def relayed(*objects)
    objects.map { |object| JSON.parse(JSON.generate(object)) }
  end

  def messages(*objects)
    Stryker::Isolation::Messages.new(relayed(*objects))
  end

  # The messages of a dry run that wrote +result+ and ended.
  def passing(result = found)
    finished = result.results.map { |test_result| { finished: test_result.as_json } }
    [{ started: sample_test.as_json }, *finished, { result: result.as_json }, { ended: true }]
  end

  def judged(said, end_of_process = ending, minutes: 5)
    dry_run = Stryker::Isolation::DryRun.within(minutes)
    Stryker::Isolation::DryRunVerdict.new(dry_run:, messages: said, ending: end_of_process).result
  end

  def refused(said, end_of_process = ending, minutes: 5)
    error = assert_raises(Stryker::Isolation::DryRunError) { judged(said, end_of_process, minutes:) }
    error.message
  end

  def test_a_dry_run_whose_tests_passed_and_whose_process_ended_cleanly_gives_what_it_found
    assert_equal(found, judged(messages(*passing)))
  end

  def test_a_failed_test_fails_the_dry_run_with_the_test_and_its_failure
    failed = found([sample_result("failed", failure_message: "Expected 90")])

    assert_match(/SampleTest#test_value failed.*\nExpected 90\z/m, refused(messages(*passing(failed))))
  end

  def test_a_dry_run_past_its_limit_names_the_option_that_sets_it
    started = messages({ started: sample_test.as_json })
    message = refused(started, ending(exit_status: nil, timed_out: true), minutes: 0.5)

    assert_includes(message, "more than 0.5 minutes")
    assert_includes(message, "dryRunTimeoutMinutes")
  end

  def test_a_dry_run_that_started_no_test_in_time_says_so
    assert_includes(refused(messages, ending(exit_status: nil, timed_out: true)), "started no test within 300 seconds")
  end

  def test_a_dry_run_that_raised_gives_the_error_and_the_end_of_standard_error
    said = messages({ error: "Stryker::Runtime::LoadingError: These instrumented files loaded" })

    assert_equal(
      "Stryker::Runtime::LoadingError: These instrumented files loaded\n[BUG] crash",
      refused(said, ending(exit_status: 1, errors: "[BUG] crash\n"))
    )
  end

  def test_a_dry_run_that_crashed_says_how_its_process_ended_and_during_which_test
    said = messages({ started: sample_test.as_json })

    assert_equal(
      "The dry run's process exited with status 3, while SampleTest#test_value ran.",
      refused(said, ending(exit_status: 3))
    )
  end

  def test_a_dry_run_that_found_something_and_then_crashed_still_fails
    assert_equal(
      "The dry run's process exited with status 1.",
      refused(messages(*passing.first(3)), ending(exit_status: 1))
    )
  end

  def test_the_dry_run_gives_what_it_found_once_it_lands
    landed = Stryker::Isolation::DryRunVerdict.awaited(Stryker::Isolation::DryRun.within(5)) do |landing|
      landing.call(messages(*passing), ending)
    end

    assert_equal(found, landed)
  end

  def test_a_dry_run_that_never_lands_is_an_error
    assert_raises(Stryker::Isolation::Error) { Stryker::Isolation::DryRunVerdict.awaited(Stryker::Isolation::DryRun.within(5)) { nil } }
  end
end
