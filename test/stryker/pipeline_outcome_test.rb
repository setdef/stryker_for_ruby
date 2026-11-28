# frozen_string_literal: true

require_relative("../test_helper")
require "stringio"
require "stryker/pipeline/outcome"

# Checks how a trial's outcome ends a run: a trial that tested its mutants
# tells the reporters the run completed, and one that stopped at a dry run that
# found no test writes a line and tells nobody.
class PipelineOutcomeTest < Minitest::Test
  def test_a_trial_that_tested_its_mutants_hands_every_reporter_a_completed_run_with_their_results
    events = []
    warnings = StringIO.new
    results = %i[first second]
    outcome = Stryker::Pipeline::Outcome.tested(results)
    outcome.announce(events.method(:push), warnings)

    assert_equal(
      [[Stryker::Events::RunCompleted.new(results:)], "", results],
      [events, warnings.string, outcome.results]
    )
  end

  def test_a_trial_that_had_no_mutant_still_completes_the_run_with_no_result
    events = []
    Stryker::Pipeline::Outcome.tested([]).announce(events.method(:push), StringIO.new)

    assert_equal([Stryker::Events::RunCompleted.new(results: [])], events)
  end

  def test_a_trial_that_stopped_at_its_dry_run_writes_one_line_and_tells_no_reporter
    events = []
    warnings = StringIO.new
    Stryker::Pipeline::Outcome.untested.announce(events.method(:push), warnings)

    assert_equal(
      [[], "The dry run found no test, so, as allowEmpty is true, no mutant was tested and no report was written.\n"],
      [events, warnings.string]
    )
  end

  def test_a_trial_that_stopped_at_its_dry_run_holds_no_result
    assert_empty(Stryker::Pipeline::Outcome.untested.results)
  end
end
