# frozen_string_literal: true

require_relative("../test_helper")
require "stryker/pipeline/outcome"

# Checks what a trial's outcome tells the listener it is given: a trial that
# tested its mutants tells it the run completed, with their results, and one
# that stopped at a dry run that found no test tells it that nothing was tested.
class PipelineOutcomeTest < Minitest::Test
  # A listener that notes what it hears.
  class Listener
    attr_reader :heard

    def initialize
      @heard = []
    end

    def completed(results)
      @heard << [:completed, results]
    end

    def nothing_tested
      @heard << [:nothing_tested]
    end
  end
  private_constant(:Listener)

  def test_a_trial_that_tested_its_mutants_tells_the_listener_the_run_completed_with_their_results
    listener = Listener.new
    results = %i[first second]
    Stryker::Pipeline::Outcome.tested(results).tell(listener)

    assert_equal([[:completed, results]], listener.heard)
  end

  def test_a_trial_that_had_no_mutant_still_tells_the_listener_the_run_completed_with_no_result
    listener = Listener.new
    Stryker::Pipeline::Outcome.tested([]).tell(listener)

    assert_equal([[:completed, []]], listener.heard)
  end

  def test_a_trial_that_stopped_at_its_dry_run_tells_the_listener_that_nothing_was_tested
    listener = Listener.new
    Stryker::Pipeline::Outcome.untested.tell(listener)

    assert_equal([[:nothing_tested]], listener.heard)
  end

  def test_each_outcome_returns_the_results_the_run_came_to
    results = %i[first second]
    outcomes = [Stryker::Pipeline::Outcome.tested(results), Stryker::Pipeline::Outcome.untested]

    assert_equal([results, []], outcomes.map { |outcome| outcome.tell(Listener.new) })
  end
end
