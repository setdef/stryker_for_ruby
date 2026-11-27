# frozen_string_literal: true

require_relative("../support/sample_values")
require_relative("../test_helper")
require "stryker/pipeline/static_runs"

# Checks when a static mutant's run runs again, with a stand-in for the
# isolation adapter, so it runs on every system.
class PipelineStaticRunsTest < Minitest::Test
  include SampleValues

  # Stands in for an isolation adapter: records the mutants' IDs of each
  # call of `run_all`, and gives each run the next status that `statuses`
  # holds for its mutant.
  class Isolation
    attr_reader :calls

    def initialize(statuses)
      @statuses = statuses
      @calls = []
    end

    def run_all(runs)
      @calls << runs.map { |run| run.mutant.id }
      runs.each { |run| yield(Stryker::MutantResult.unrun(run.mutant, @statuses[run.mutant.id].shift)) }
    end
  end

  def static_run(id)
    mutant_run.with(mutant: mutant.with(id:), static: true)
  end

  def run_static(statuses)
    isolation = Isolation.new(statuses)
    results = []
    Stryker::Pipeline::StaticRuns.new(isolation).run_all(statuses.keys.map { |id| static_run(id) }) do |result|
      results << [result.mutant.id, result.status]
    end
    [isolation.calls, results]
  end

  def test_a_run_that_timed_out_runs_again_alone_once_every_other_run_has_ended
    calls, = run_static({ 1 => %w[Timeout Survived], 2 => %w[Killed], 3 => %w[Timeout Killed] })

    assert_equal([[1, 2, 3], [1], [3]], calls)
  end

  def test_a_mutant_whose_run_timed_out_has_the_status_of_its_run_alone
    _, results = run_static({ 1 => %w[Timeout Survived], 2 => %w[Survived], 3 => %w[Timeout Killed] })

    assert_equal([[2, "Survived"], [1, "Survived"], [3, "Killed"]], results)
  end

  def test_a_mutant_whose_run_times_out_alone_too_has_the_status_timeout
    calls, results = run_static({ 1 => %w[Timeout Timeout] })

    assert_equal([[[1], [1]], [[1, "Timeout"]]], [calls, results])
  end

  def test_a_run_that_did_not_time_out_runs_once
    calls, results = run_static({ 1 => %w[Survived], 2 => %w[RuntimeError] })

    assert_equal([[[1, 2]], [[1, "Survived"], [2, "RuntimeError"]]], [calls, results])
  end
end
