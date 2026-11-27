# frozen_string_literal: true

require_relative("../test_helper")
require "stryker/dry_run_result"
require "stryker/mutant_result"
require "stryker/mutant_run"

# Builds one of each value that passes between the stages, so that the tests
# of a value and of the values that hold it share their samples.
module SampleValues
  def position
    Stryker::Position.new(line: 8, column: 3)
  end

  def location
    Stryker::Location.new(start: position, end: Stryker::Position.new(line: 12, column: 6))
  end

  def test_definition
    Stryker::Test.new(
      id: "Shop::DiscountTest#test_rate",
      name: "test_rate",
      file: "test/shop/discount_test.rb",
      location:
    )
  end

  def test_result(status: "failed", failure_message: "Expected 90, got 100")
    Stryker::TestResult.new(test: test_definition, status:, failure_message:, duration_ms: 0.25)
  end

  def dry_run_result
    Stryker::DryRunResult.new(
      results: [test_result, test_result(status: "passed", failure_message: nil)],
      buckets: { "Shop::DiscountTest#test_rate": [3, 4] }.transform_keys(&:to_s),
      static_bucket: [1],
      files_loaded_in_tests: ["lib/shop/tax.rb"],
      duration_ms: 1.75
    )
  end

  def mutant
    Stryker::Mutant.new(
      id: 7,
      file: "lib/shop/discount.rb",
      mutator_name: "EqualityOperator",
      start_offset: 10,
      end_offset: 11,
      replacement: "-"
    )
  end

  def mutant_run
    Stryker::MutantRun.new(
      mutant:,
      static: false,
      test_ids: ["Shop::DiscountTest#test_rate"],
      covered_by: ["Shop::DiscountTest#test_rate"],
      timeout_ms: 1500
    )
  end

  def mutant_result(status: "Killed")
    Stryker::MutantResult.new(
      mutant:,
      status:,
      status_reason: "Expected 90, got 100",
      killed_by: ["Shop::DiscountTest#test_rate"],
      covered_by: ["Shop::DiscountTest#test_rate"],
      tests_completed: 1,
      duration_ms: 41.5,
      static: false
    )
  end
end
