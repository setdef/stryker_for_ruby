# frozen_string_literal: true

require "digest"

module Stryker
  module Mutators
    class Roster
      def initialize(file:, source:, first_id:)
        @file = file
        @source = source
        @first_id = first_id
      end

      def mutants(candidates)
        seen = Set[Digest::SHA256.digest(@source)]
        candidates.each_with_object([]) do |candidate, kept|
          mutant = candidate.mutant(@file, @first_id + kept.size)
          kept << mutant if seen.add?(Digest::SHA256.digest(mutant.edit(@source)))
        end
      end
    end
  end
end
