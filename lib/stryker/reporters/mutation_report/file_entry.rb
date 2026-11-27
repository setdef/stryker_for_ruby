# frozen_string_literal: true

require_relative "mutant_entry"

module Stryker
  module Reporters
    class MutationReport
      class FileEntry
        attr_reader :mutants

        def initialize(file, results)
          @file = file
          @mutants = results.map { |result| MutantEntry.new(result, file) }
        end

        def path
          @file.name
        end

        def statuses
          @mutants.map(&:status)
        end

        def mutant_count
          @mutants.size
        end

        def pair
          [path, to_h]
        end

        def tests_completed
          @mutants.sum(&:tests_completed)
        end

        def to_h
          { language: @file.language, source: @file.source, mutants: @mutants.map(&:to_h) }
        end

        # @dynamic mutants
      end
    end
  end
end
