# frozen_string_literal: true

require_relative("../support/sample_values")
require_relative("../test_helper")

# Checks that a dry run result holds each test's result and bucket, the static
# bucket, and the files first loaded during a test, compares by value, and
# survives a round trip through JSON.
class DryRunResultTest < Minitest::Test
  include SampleValues

  def test_holds_its_members
    result = dry_run_result

    assert_equal(
      [
        [test_result, test_result(status: "passed", failure_message: nil)],
        { "Shop::DiscountTest#test_rate": [3, 4] }.transform_keys(&:to_s),
        [1],
        ["lib/shop/tax.rb"],
      ],
      [result.results, result.buckets, result.static_bucket, result.files_loaded_in_tests]
    )
  end

  def test_results_with_equal_members_are_equal
    assert_equal(dry_run_result, Stryker::DryRunResult.new(*dry_run_result.to_h.values))
  end

  def test_results_with_different_static_buckets_differ
    refute_equal(dry_run_result, Stryker::DryRunResult.new(**dry_run_result.to_h, static_bucket: [2]))
  end

  def test_a_round_trip_through_json_gives_an_equal_result
    assert_equal(dry_run_result, Stryker::DryRunResult.from_json(dry_run_result.to_json))
  end

  def test_a_dry_run_of_no_tests_survives_a_round_trip
    result = Stryker::DryRunResult.new(results: [], buckets: {}, static_bucket: [], files_loaded_in_tests: [])

    assert_equal(result, Stryker::DryRunResult.from_json(result.to_json))
  end

  def test_a_missing_list_of_results_is_refused
    object = { buckets: {}, static_bucket: [], files_loaded_in_tests: [] }.transform_keys(&:to_s)

    assert_raises(ArgumentError) { Stryker::DryRunResult.from_h(object) }
  end
end
