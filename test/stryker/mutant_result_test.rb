# frozen_string_literal: true

require_relative("../support/sample_values")
require_relative("../test_helper")

# Checks that a mutant result holds its members, compares by value, refuses a
# status the report schema doesn't have, and survives a round trip through
# JSON.
class MutantResultTest < Minitest::Test
  include SampleValues

  def test_holds_its_members
    result = mutant_result

    assert_equal(
      [mutant, "Killed", "Expected 90, got 100", ["Shop::DiscountTest#test_rate"], ["Shop::DiscountTest#test_rate"]],
      [result.mutant, result.status, result.status_reason, result.killed_by, result.covered_by]
    )
    assert_equal([1, 41.5, false], [result.tests_completed, result.duration_ms, result.static])
  end

  def test_results_with_equal_members_are_equal
    assert_equal(mutant_result, Stryker::MutantResult.new(*mutant_result.to_h.values))
  end

  def test_results_with_different_statuses_differ
    refute_equal(mutant_result, mutant_result(status: "Survived"))
  end

  def test_the_statuses_are_the_report_schemas_without_pending
    assert_equal(%w[Killed Survived NoCoverage CompileError RuntimeError Timeout Ignored], Stryker::MutantResult::STATUSES)
  end

  def test_each_status_is_accepted
    statuses = Stryker::MutantResult::STATUSES.map { |status| mutant_result(status:).status }

    assert_equal(Stryker::MutantResult::STATUSES, statuses)
  end

  def test_a_status_the_schema_does_not_have_is_refused
    error = assert_raises(ArgumentError) { mutant_result(status: "Pending") }

    statuses = Stryker::MutantResult::STATUSES.join(", ")

    assert_equal(%(unknown mutant status "Pending", expected one of #{statuses}), error.message)
  end

  def test_a_status_that_is_not_a_string_is_refused
    assert_raises(ArgumentError) { mutant_result(status: :Killed) }
  end

  def test_a_status_the_schema_does_not_have_is_refused_when_read_from_json
    assert_raises(ArgumentError) { Stryker::MutantResult.from_json(mutant_result.to_json.sub("Killed", "Dead")) }
  end

  def test_a_round_trip_through_json_gives_an_equal_result
    assert_equal(mutant_result, Stryker::MutantResult.from_json(mutant_result.to_json))
  end

  def test_a_result_of_a_mutant_that_did_not_run_survives_a_round_trip
    result = Stryker::MutantResult.new(
      **mutant_result.to_h,
      status: "NoCoverage",
      status_reason: nil,
      killed_by: [],
      tests_completed: nil,
      duration_ms: nil
    )

    assert_equal(result, Stryker::MutantResult.from_json(result.to_json))
  end

  def test_a_missing_mutant_is_refused
    assert_raises(ArgumentError) { Stryker::MutantResult.from_h({ status: "Killed" }.transform_keys(&:to_s)) }
  end
end
