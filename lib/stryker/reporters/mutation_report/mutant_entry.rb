# frozen_string_literal: true

require_relative "../mutant_excerpt"
require_relative "mutant_document"

module Stryker
  module Reporters
    class MutationReport
      class MutantEntry
        UNDETECTED = %w[Survived NoCoverage].freeze
        private_constant(:UNDETECTED)

        def initialize(result, file)
          @result = result
          @file = file
        end

        def display_path
          @file.display_name
        end

        def status
          @result.status
        end

        def survived?
          status == "Survived"
        end

        def undetected?
          UNDETECTED.include?(status)
        end

        def mutator_name
          mutant.mutator_name
        end

        def location
          @file.location(mutant.start_offset, mutant.end_offset)
        end

        def excerpt
          MutantExcerpt.new(@file.source, location, mutant.replacement)
        end

        def covered_by
          @result.covered_by
        end

        def killed_by
          @result.killed_by
        end

        def static?
          @result.static
        end

        def tests_completed
          @result.tests_completed || 0
        end

        def to_h
          MutantDocument.new(@result, location).to_h
        end

        private def mutant
          @result.mutant
        end
      end
    end
  end
end
