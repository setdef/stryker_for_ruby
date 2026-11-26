# frozen_string_literal: true

require_relative "candidate"
require_relative "roster"
require_relative "traversal"

module Stryker
  module Mutators
    class Walk
      def initialize(file:, result:, mutators:, first_id: 1)
        raise(ArgumentError, "#{file} doesn't parse, so it has no sites") unless result.success?

        @tree = result.value
        @mutators = mutators
        @roster = Roster.new(file:, source: result.source.source, first_id:)
      end

      def mutants
        @roster.mutants(@mutators.flat_map { |mutator| Candidate.in_order(candidates_of(mutator)) })
      end

      private def candidates_of(mutator)
        # @type var found: Array[Candidate]
        found = []
        Traversal.new(@tree).each { |node, ancestors| found.concat(Candidate.at(mutator, node, ancestors)) }
        found
      end
    end
  end
end
