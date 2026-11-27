# frozen_string_literal: true

require_relative("../support/sample_plan")
require_relative("../test_helper")

# Checks that the plan gives each mutant NoCoverage, a static run of every
# test that passed, or a runtime run of the tests that passed and reached it,
# and that it refuses a dry run with a bucket for a test it has no result for.
class PlanTest < Minitest::Test
  include SamplePlan

  def test_a_mutant_that_no_test_reached_has_no_coverage
    plan = plan_of([mutant(9)])

    assert_equal([[], [no_coverage(9)]], [plan.runs, plan.unrun])
  end

  def test_a_mutant_that_tests_reached_runs_those_tests
    run = plan_of([mutant(3)]).runs.first

    assert_equal([false, [RATE, BULK], [RATE, BULK]], [run.static, run.test_ids, run.covered_by])
  end

  def test_a_static_mutant_runs_every_test_that_passed
    run = plan_of([mutant(1)]).runs.first

    assert_equal([true, [RATE, BULK], []], [run.static, run.test_ids, run.covered_by])
  end

  def test_a_static_mutant_that_a_test_reached_lists_that_test_as_covering_it
    run = plan_of([mutant(5)]).runs.first

    assert_equal([true, [RATE, BULK], [BULK]], [run.static, run.test_ids, run.covered_by])
  end

  def test_a_mutant_that_only_a_skipped_test_reached_has_no_coverage
    assert_equal([no_coverage(4)], plan_of([mutant(4)]).unrun)
  end

  def test_a_skipped_test_is_left_out_of_a_run_and_its_coverage
    run = plan_of([mutant(6)]).runs.first

    assert_equal([[RATE], [RATE]], [run.test_ids, run.covered_by])
  end

  def test_a_static_mutant_with_no_test_that_passed_has_no_coverage
    dry_run = dry_run(results: [result(LATER, 2.0, "skipped")], buckets: {}, static_bucket: [1])

    assert_equal([no_coverage(1)], plan_of([mutant(1)], dry_run).unrun)
  end

  def test_the_mutants_keep_their_order
    plan = plan_of([mutant(9), mutant(3), mutant(8), mutant(1)])
    ids = [plan.runs.map(&:mutant), plan.unrun.map(&:mutant)].map { |mutants| mutants.map(&:id) }

    assert_equal([[3, 1], [9, 8]], ids)
  end

  def test_a_bucket_of_a_test_with_no_result_stops_the_plan
    gone = %w[a b].map { |name| "Shop::GoneTest#test_#{name}" }
    dry_run = dry_run(buckets: { RATE => [3], gone.first => [3], gone.last => [] })

    error = assert_raises(Stryker::Plan::Error) { plan_of([mutant(3)], dry_run) }
    assert_equal(
      'The dry run recorded the mutants that "Shop::GoneTest#test_a" and "Shop::GoneTest#test_b" reached, ' \
        "and has no result for them, so Stryker (for Ruby) can't tell whether they passed. " \
        "The test runner adapter has a fault: it reported their start without their result.",
      error.message
    )
  end

  private def no_coverage(id)
    Stryker::MutantResult.new(
      mutant: mutant(id),
      status: "NoCoverage",
      status_reason: nil,
      killed_by: [],
      covered_by: [],
      tests_completed: nil,
      duration_ms: nil,
      static: false
    )
  end
end
