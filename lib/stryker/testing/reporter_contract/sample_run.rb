# frozen_string_literal: true

require_relative "../../events"
require_relative "../../mutant"
require_relative "../../mutant_result"
require_relative "../../mutant_run"
require_relative "sample_project"

module Stryker
  module Testing
    module ReporterContract
      module SampleRun
        def self.result(from, to, id = 1)
          MutantResult.new(
            mutant: mutant(from, to, id),
            status: "Survived",
            status_reason: nil,
            killed_by: %w[],
            covered_by: [SampleProject::LABEL_TEST],
            tests_completed: 1,
            duration_ms: 4.5,
            static: false
          )
        end

        def self.survivor
          result("> 100", ">= 100")
        end

        def self.killed(id: 2)
          result("* 2", "/ 2", id).with(
            status: "Killed",
            status_reason: "Expected 4, got 1",
            killed_by: [SampleProject::RATE_TEST],
            covered_by: [SampleProject::RATE_TEST]
          )
        end

        def self.not_covered
          result("100", "101", 3).with(status: "NoCoverage", covered_by: %w[], tests_completed: nil, duration_ms: nil)
        end

        def self.events
          results = [survivor, killed, not_covered]
          [
            SampleProject.dry_run_completed,
            plan_ready(results),
            *results.map { |result| Events::MutantTested.new(result:) },
            Events::RunCompleted.new(results:),
          ]
        end

        def self.without_mutants
          none = Array(nil)
          [
            SampleProject.dry_run_completed,
            Events::PlanReady.new(runs: none, unrun: none),
            Events::RunCompleted.new(results: none),
          ]
        end

        def self.of_every_status
          statuses = MutantResult::STATUSES.each_with_index
          Events::RunCompleted.new(results: statuses.map { |status, id| result("> 100", ">= 100", id).with(status:) })
        end

        def self.mutant(from, to, id)
          start_offset = SampleProject::SOURCE.byteindex(from) or raise(ArgumentError, "#{from} isn't in the sample")
          Mutant.new(
            id:,
            file: SampleProject::SOURCE_FILE,
            mutator_name: "EqualityOperator",
            start_offset:,
            end_offset: start_offset + from.bytesize,
            replacement: to
          )
        end

        def self.plan_ready(results)
          run = MutantRun.new(
            mutant: survivor.mutant,
            static: false,
            test_ids: [SampleProject::LABEL_TEST],
            covered_by: [SampleProject::LABEL_TEST],
            timeout_ms: 1500
          )
          Events::PlanReady.new(runs: [run], unrun: results.select { |result| result.status == "NoCoverage" })
        end
        private_class_method(:mutant, :plan_ready)
      end
    end
  end
end
