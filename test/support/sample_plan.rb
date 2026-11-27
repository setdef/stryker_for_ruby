# frozen_string_literal: true

require_relative("../test_helper")
require "stryker/config"
require "stryker/dry_run_result"
require "stryker/mutant"
require "stryker/plan"

# A dry run of three tests to plan from, so that the tests of the plan's
# statuses and of its time limits share it. test_rate took 100 ms and reached
# mutants 3 and 6, test_later was skipped after it reached 4 and 6, and
# test_bulk took 20 ms and reached 3 and 5. Mutants 1 and 5 are static, and
# the dry run took 200 ms, so its overhead is 50 ms.
module SamplePlan
  RATE = "Shop::DiscountTest#test_rate"
  BULK = "Shop::DiscountTest#test_bulk"
  LATER = "Shop::DiscountTest#test_later"
  public_constant(:RATE, :BULK, :LATER)

  private def plan_of(mutants, dry_run = self.dry_run, config = self.config)
    Stryker::Plan.new(dry_run, config).call(mutants)
  end

  private def config
    Stryker::Config.new(mutate: [], test_runner: "minitest")
  end

  private def dry_run(**changes)
    Stryker::DryRunResult.new(
      results: [result(RATE, 100.0), result(LATER, 30.0, "skipped"), result(BULK, 20.0)],
      buckets: { RATE => [3, 6], BULK => [3, 5], LATER => [4, 6] },
      static_bucket: [1, 5],
      files_loaded_in_tests: [],
      duration_ms: 200.0,
      **changes
    )
  end

  private def result(id, duration_ms, status = "passed")
    test = Stryker::Test.new(id:, name: id.split("#").last, file: "test/shop/discount_test.rb", location: nil)
    Stryker::TestResult.new(test:, status:, failure_message: nil, duration_ms:)
  end

  private def mutant(id)
    Stryker::Mutant.new(
      id:,
      file: "lib/shop/discount.rb",
      mutator_name: "EqualityOperator",
      start_offset: 10,
      end_offset: 11,
      replacement: "!="
    )
  end
end
