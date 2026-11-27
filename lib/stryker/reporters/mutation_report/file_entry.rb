# frozen_string_literal: true

require_relative "mutant_entry"

module Stryker
  module Reporters
    class MutationReport
      class FileEntry
        def initialize(file, results)
          @file = file
          @results = results
        end

        def to_h
          {
            language: @file.language,
            source: @file.source,
            mutants: @results.map { |result| MutantEntry.new(result, @file).to_h },
          }
        end
      end
    end
  end
end
