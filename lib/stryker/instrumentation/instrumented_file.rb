# frozen_string_literal: true

module Stryker
  class Instrumentation
    class InstrumentedFile < Data.define(:path, :source, :mutants, :unrun, :mutant_count)
      def self.of(path, mutants, result)
        skipped = result.skipped
        new(
          path:,
          source: result.source,
          mutants: mutants - skipped.map(&:mutant),
          unrun: skipped.map(&:result),
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
