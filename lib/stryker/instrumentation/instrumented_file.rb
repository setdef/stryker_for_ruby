# frozen_string_literal: true

require_relative "../mutant_result"

module Stryker
  class Instrumentation
    class InstrumentedFile < Data.define(:path, :source, :mutants, :unrun, :mutant_count)
      INVALID = :does_not_parse
      private_constant(:INVALID)

      def self.of(path, mutants, result)
        skipped = result.skipped
        invalid = skipped.filter_map { |skip| skip.mutant if skip.reason == INVALID }
        new(
          path:,
          source: result.source,
          mutants: mutants - skipped.map(&:mutant),
          unrun: invalid.map { |mutant| MutantResult.unrun(mutant, "CompileError") },
          mutant_count: mutants.size
        )
      end

      def self.next_id(files)
        files.sum(&:mutant_count) + 1
      end

      # @dynamic path, source, mutants, unrun, mutant_count
    end
  end
end
