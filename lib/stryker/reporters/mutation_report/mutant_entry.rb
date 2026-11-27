# frozen_string_literal: true

require_relative "span"

module Stryker
  module Reporters
    class MutationReport
      class MutantEntry
        def initialize(result, file)
          @result = result
          @file = file
        end

        def to_h
          { **where, **outcome }.reject { |_name, value| Array(value).empty? }
        end

        private def where
          { id: mutant.id.to_s, mutatorName: mutant.mutator_name, replacement: mutant.replacement, location: }
        end

        private def location
          Span.new(@file.location(mutant.start_offset, mutant.end_offset)).to_h
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
