# frozen_string_literal: true

require_relative("../../support/sample_values")
require_relative("../../test_helper")
require "stryker/events"

# Checks that each domain event holds what its stage publishes and compares by
# value.
class EventsTest < Minitest::Test
  include SampleValues

  def test_a_dry_run_completed_holds_the_dry_run_result
    assert_equal(dry_run_result, Stryker::Events::DryRunCompleted.new(result: dry_run_result).result)
  end

  def test_a_plan_ready_holds_the_runs_and_the_mutants_that_wont_run
    event = Stryker::Events::PlanReady.new(runs: [mutant_run], unrun: [mutant_result(status: "NoCoverage")])

    assert_equal([[mutant_run], [mutant_result(status: "NoCoverage")]], [event.runs, event.unrun])
  end

  def test_a_mutant_tested_holds_the_result
    assert_equal(mutant_result, Stryker::Events::MutantTested.new(result: mutant_result).result)
  end

  def test_a_run_completed_holds_every_result
    results = [mutant_result, mutant_result(status: "Survived")]

    assert_equal(results, Stryker::Events::RunCompleted.new(results:).results)
  end

  def test_a_run_aborted_holds_the_error_that_stopped_the_run
    error = RuntimeError.new("boom")

    assert_same(error, Stryker::Events::RunAborted.new(error:).error)
  end

  def test_events_with_equal_members_are_equal
    event = Stryker::Events::MutantTested.new(mutant_result)

    assert_equal(event, Stryker::Events::MutantTested.new(result: mutant_result))
  end

  def test_events_with_different_members_differ
    event = Stryker::Events::MutantTested.new(mutant_result)

    refute_equal(event, Stryker::Events::MutantTested.new(mutant_result(status: "Survived")))
  end

  def test_events_of_different_kinds_differ
    event = Stryker::Events::MutantTested.new(mutant_result)

    refute_equal(event, Stryker::Events::DryRunCompleted.new(mutant_result))
  end
end
