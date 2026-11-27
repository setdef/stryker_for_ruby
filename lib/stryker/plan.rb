# frozen_string_literal: true

require_relative "events/plan_ready"
require_relative "mutant_result"
require_relative "mutant_run"
require_relative "plan/error"
require_relative "plan/map"
require_relative "plan/time_limit"

module Stryker
  class Plan
    def self.ids(results)
      results.map { |result| result.test.id }
    end

    def self.no_coverage(mutants)
      mutants.map { |mutant| no_coverage_of(mutant) }
    end

    def self.no_coverage_of(mutant)
      MutantResult.new(
        mutant:,
        status: "NoCoverage",
        status_reason: nil,
        killed_by: [],
        covered_by: [],
        tests_completed: nil,
        duration_ms: nil,
        static: false
      )
    end

    def initialize(dry_run, config)
      @map = Map.new(dry_run)
      @time_limit = TimeLimit.new(dry_run, config)
    end

    def call(mutants)
      covered, uncovered = mutants.partition { |mutant| @map.tests(mutant.id).any? }
      Events::PlanReady.new(runs: runs(covered), unrun: Plan.no_coverage(uncovered))
    end

    private def runs(mutants)
      mutants.map { |mutant| run(mutant) }
    end

    private def run(mutant)
      id = mutant.id
      tests = @map.tests(id)
      MutantRun.new(
        mutant:,
        static: @map.static?(id),
        test_ids: Plan.ids(tests),
        covered_by: Plan.ids(@map.covering(id)),
        timeout_ms: @time_limit.of(tests)
      )
    end
  end
end
