# frozen_string_literal: true

require_relative "span"

module Stryker
  module Reporters
    class MutationReport
      class MutantDocument
        def initialize(result, location)
          @result = result
          @location = location
        end

        def to_h
          { **where, **outcome }.reject { |_name, value| Array(value).empty? }
        end

        private def where
          {
            id: mutant.id.to_s,
            mutatorName: mutant.mutator_name,
            replacement: mutant.replacement,
            location: Span.new(@location).to_h,
          }
        end

        private def mutant
          @result.mutant
        end

        private def outcome
          {
            status: @result.status,
            statusReason: @result.status_reason,
            coveredBy: @result.covered_by,
            killedBy: @result.killed_by,
            testsCompleted: @result.tests_completed,
            duration: @result.duration_ms,
            static: @result.static,
          }
        end
      end
    end
  end
end
