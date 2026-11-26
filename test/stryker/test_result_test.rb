# frozen_string_literal: true

require_relative("../support/sample_values")
require_relative("../test_helper")

# Checks that a test result holds its members, compares by value, refuses a
# status it doesn't know, and survives a round trip through JSON.
class TestResultTest < Minitest::Test
  include SampleValues

  def test_holds_its_members
    assert_equal(
      { test: test_definition, status: "failed", failure_message: "Expected 90, got 100", duration_ms: 0.25 },
      test_result.to_h
    )
  end

  def test_results_with_equal_members_are_equal
    assert_equal(test_result, Stryker::TestResult.new(*test_result.to_h.values))
  end

  def test_results_with_different_statuses_differ
    refute_equal(test_result, test_result(status: "skipped"))
  end

  def test_each_status_is_accepted
    statuses = Stryker::TestResult::STATUSES.map { |status| test_result(status:).status }

    assert_equal(Stryker::TestResult::STATUSES, statuses)
  end

  def test_the_statuses_are_passed_failed_and_skipped
    assert_equal(%w[passed failed skipped], Stryker::TestResult::STATUSES)
  end

  def test_a_status_it_does_not_know_is_refused
    error = assert_raises(ArgumentError) { test_result(status: "failure") }

    assert_equal('unknown test status "failure", expected one of passed, failed, skipped', error.message)
  end

  def test_a_status_that_is_not_a_string_is_refused
    assert_raises(ArgumentError) { test_result(status: :failed) }
  end

  def test_a_status_it_does_not_know_is_refused_when_read_from_json
    text = test_result.to_json.sub("failed", "failure")

    assert_raises(ArgumentError) { Stryker::TestResult.from_json(text) }
  end

  def test_a_round_trip_through_json_gives_an_equal_result
    assert_equal(test_result, Stryker::TestResult.from_json(test_result.to_json))
  end

  def test_a_result_with_no_message_survives_a_round_trip
    result = test_result(status: "passed", failure_message: nil)

    assert_equal(result, Stryker::TestResult.from_json(result.to_json))
  end

  def test_a_message_that_is_not_valid_utf_8_is_written_with_replacement_characters
    result = test_result(failure_message: "bad \xFF byte")

    assert_equal("bad \u{FFFD} byte", Stryker::TestResult.from_json(result.to_json).failure_message)
  end

  def test_a_binary_message_is_written_with_replacement_characters
    result = test_result(failure_message: "caf\xC3\xA9 \xFF".b)

    assert_equal("caf\u{FFFD}\u{FFFD} \u{FFFD}", Stryker::TestResult.from_json(result.to_json).failure_message)
  end

  def test_a_message_in_another_encoding_is_written_in_utf8
    result = test_result(failure_message: "caf\xE9".dup.force_encoding(Encoding::ISO_8859_1))

    assert_equal("café", Stryker::TestResult.from_json(result.to_json).failure_message)
  end
end
