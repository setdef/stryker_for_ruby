# frozen_string_literal: true

require_relative("../support/pipeline_run")
require_relative("../support/sample_values")
require_relative("../test_helper")
require "stryker/config_error"
require "stryker/pipeline"

# Checks how the pipeline composes the stages and owns what a run starts,
# with stand-ins for the isolation adapters, so it runs on every system.
class PipelineTest < Minitest::Test
  include PipelineRun
  include SampleValues

  def test_the_score_counts_every_mutant
    assert_in_delta(100.0 / 3, run_pipeline(Isolations.new(found:)))
  end

  def test_the_runtime_adapter_runs_the_dry_run_and_the_runtime_mutants_and_the_static_adapter_the_static_ones
    isolations = Isolations.new(found:)
    run_pipeline(isolations)

    calls = ["runtime start", "static start", "runtime dry_run", "runtime run_all 1", "static run_all 2"]

    assert_equal([*calls, "runtime stop", "static stop"], isolations.calls)
  end

  def test_every_reporter_receives_each_event_in_the_order_the_run_publishes_it
    run_pipeline(Isolations.new(found:))
    first, second = @reporters.map { |reporter| reporter.events.map(&:class) }
    events = Stryker::Events
    tested = [events::MutantTested] * 3

    assert_equal([events::DryRunCompleted, events::PlanReady, *tested, events::RunCompleted], first)
    assert_equal(first, second)
  end

  def test_the_mutants_that_did_not_run_are_tested_first
    run_pipeline(Isolations.new(found:))
    tested = @reporters.first.events.grep(Stryker::Events::MutantTested)

    assert_equal([3, 1, 2], tested.map { |event| event.result.mutant.id })
  end

  def test_the_run_completes_with_every_result_in_the_order_of_the_ids
    run_pipeline(Isolations.new(found:))
    completed = @reporters.first.events.last.results

    statuses = completed.map { |result| [result.mutant.id, result.status] }

    assert_equal([[1, "Killed"], [2, "Survived"], [3, "NoCoverage"]], statuses)
  end

  def test_the_dry_run_and_the_plan_reach_the_reporters_as_they_were_found
    run_pipeline(Isolations.new(found:))
    dry_run, plan = @reporters.first.events.first(2)

    assert_equal(found, dry_run.result)
    assert_equal([[1, false], [2, true]], plan.runs.map { |run| [run.mutant.id, run.static] })
  end

  def test_the_cache_is_gone_after_the_run
    isolations = Isolations.new(found:)
    run_pipeline(isolations)

    refute(Dir.exist?(isolations.cache))
  end

  def test_an_interrupt_stops_both_adapters_and_deletes_the_cache_before_it_ends_the_run
    isolations = Isolations.new(found:, raises: Interrupt)

    assert_raises(Interrupt) { run_pipeline(isolations) }
    assert_equal(["runtime stop", "static stop"], isolations.calls.last(2))
    refute(Dir.exist?(isolations.cache))
  end

  def test_an_interrupted_run_never_completes_and_ends_with_the_interrupt
    assert_raises(Interrupt) { run_pipeline(Isolations.new(found:, raises: Interrupt)) }
    events = Stryker::Events

    assert_equal(
      [events::DryRunCompleted, events::PlanReady, events::MutantTested, events::RunAborted],
      @reporters.first.events.map(&:class)
    )
    assert_instance_of(Interrupt, @reporters.first.events.last.error)
  end

  def test_a_dry_run_that_found_no_test_stops_the_run_before_any_mutant_runs
    isolations = Isolations.new(found: found_no_test)

    error = assert_raises(Stryker::ConfigError) { run_pipeline(isolations) }

    assert_equal(["runtime start", "static start", "runtime dry_run", "runtime stop", "static stop"], isolations.calls)
    assert_match(/no test.*minitest\.testFiles.*allowEmpty/m, error.message)
  end

  def test_a_run_that_stopped_for_want_of_a_test_is_aborted_with_that_error_and_never_completes
    assert_raises(Stryker::ConfigError) { run_pipeline(Isolations.new(found: found_no_test)) }
    events = @reporters.first.events

    assert_equal([Stryker::Events::RunAborted], events.map(&:class))
    assert_instance_of(Stryker::ConfigError, events.first.error)
  end

  def test_a_dry_run_that_found_no_test_goes_on_when_allow_empty_is_true_with_every_mutant_no_coverage
    isolations = Isolations.new(found: found_no_test)
    run_pipeline(isolations, options: { allow_empty: true })
    completed = @reporters.first.events.last.results

    assert_equal(%w[NoCoverage] * 3, completed.map(&:status))
    assert_includes(isolations.calls, "runtime run_all")
  end

  def test_a_dry_run_that_found_a_test_goes_on_whatever_allow_empty_holds
    [true, false].each do |allow_empty|
      assert_in_delta(100.0 / 3, run_pipeline(Isolations.new(found:), options: { allow_empty: }))
    end
  end
end
