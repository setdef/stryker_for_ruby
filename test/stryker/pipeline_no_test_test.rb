# frozen_string_literal: true

require_relative("../support/pipeline_run")
require_relative("../support/sample_values")
require_relative("../test_helper")
require "stringio"
require "stryker/config_error"
require "stryker/pipeline"

# Checks what the pipeline does with a dry run that found no test, with
# stand-ins for the isolation adapters, so it runs on every system.
class PipelineNoTestTest < Minitest::Test
  include PipelineRun
  include SampleValues

  def test_a_dry_run_that_found_no_test_stops_the_run_before_any_mutant_runs
    isolations = Isolations.new(found: found_no_test)

    error = assert_raises(Stryker::ConfigError) { run_pipeline(isolations) }

    assert_equal(["runtime start", "static start", "runtime dry_run", "runtime stop", "static stop"], isolations.calls)
    assert_match(/no test.*minitest\.testFiles.*allowEmpty/m, error.message)
  end

  def test_a_run_that_stopped_for_want_of_a_test_is_aborted_with_that_error_and_never_completes
    assert_raises(Stryker::ConfigError) { run_pipeline(Isolations.new(found: found_no_test)) }
    events = @reporters.first.events

    assert_equal([Stryker::Events::DryRunCompleted, Stryker::Events::RunAborted], events.map(&:class))
    assert_instance_of(Stryker::ConfigError, events.last.error)
  end

  def test_every_reporter_hears_that_a_dry_run_that_found_no_test_completed_before_the_run_is_aborted
    assert_raises(Stryker::ConfigError) { run_pipeline(Isolations.new(found: found_no_test)) }
    dry_run = @reporters.map { |reporter| reporter.events.first }

    assert_equal([found_no_test] * 2, dry_run.map(&:result))
  end

  def test_a_dry_run_that_found_no_test_ends_the_run_with_no_mutant_tested_when_allow_empty_is_true
    isolations = Isolations.new(found: found_no_test)
    run_pipeline(isolations, options: { allow_empty: true })

    assert_equal(["runtime start", "static start", "runtime dry_run", "runtime stop", "static stop"], isolations.calls)
  end

  def test_such_a_run_tells_the_reporters_only_of_the_dry_run
    run_pipeline(Isolations.new(found: found_no_test), options: { allow_empty: true })

    assert_equal([Stryker::Events::DryRunCompleted], @reporters.first.events.map(&:class))
  end

  def test_such_a_run_has_no_score_for_thresholds_break_to_judge
    assert_nil(run_pipeline(Isolations.new(found: found_no_test), options: { allow_empty: true }))
  end

  def test_such_a_run_writes_one_line_to_the_warnings_stream_that_says_why_it_tested_no_mutant
    warnings = StringIO.new
    run_pipeline(Isolations.new(found: found_no_test), options: { allow_empty: true }, warnings:)

    assert_equal(
      "The dry run found no test, so, as allowEmpty is true, no mutant was tested and no report was written.\n",
      warnings.string
    )
  end

  def test_a_run_that_tested_its_mutants_writes_nothing_to_the_warnings_stream
    warnings = StringIO.new
    run_pipeline(Isolations.new(found:), options: { allow_empty: true }, warnings:)

    assert_empty(warnings.string)
  end
end
