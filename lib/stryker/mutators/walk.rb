# frozen_string_literal: true

require_relative "../mutators"
require_relative "candidate"
require_relative "occupancy"
require_relative "roster"
require_relative "search"

module Stryker
  module Mutators
    class Walk
      def initialize(file:, result:, mutators: ALL, fallbacks: FALLBACKS, first_id: 1)
        raise(ArgumentError, "#{file} doesn't parse, so it has no sites") unless result.success?

        @search = Search.new(result.value, file)
        @mutators = mutators
        @fallbacks = fallbacks
        @roster = Roster.new(file:, source: result.source.source, first_id:)
      end

      def mutants
        @roster.mutants(made(@mutators.flat_map { |mutator| Candidate.in_order(@search.candidates_of(mutator)) }))
      end

      private def made(candidates)
        occupancy = Occupancy.new(candidates)
        candidates.select { |candidate| !@fallbacks.include?(candidate.mutator) || occupancy.alone?(candidate) }
      end
    end
  end
end
