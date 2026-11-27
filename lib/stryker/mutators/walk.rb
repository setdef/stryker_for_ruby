# frozen_string_literal: true

require_relative "../mutators"
require_relative "candidate"
require_relative "occupancy"
require_relative "policy"
require_relative "roster"
require_relative "search"

module Stryker
  module Mutators
    class Walk
      def initialize(file:, result:, mutators: ALL, first_id: 1, policy: Policy.new)
        raise(ArgumentError, "#{file} doesn't parse, so it has no sites") unless result.success?

        @search = Search.new(result.value, file)
        @mutators = mutators
        @policy = policy
        @roster = Roster.new(file:, source: result.source.source, first_id:)
      end

      def mutants
        made.mutants
      end

      def ignored
        made.ignored
      end

      def made
        @made ||= @roster.made(chosen(judged(@mutators.flat_map { |mutator| found_by(mutator) })))
      end

      private def found_by(mutator)
        Candidate.in_order(@search.candidates_of(mutator))
      end

      private def judged(candidates)
        candidates.map { |candidate| candidate.ignored_because(@policy.reason(candidate)) }
      end

      private def chosen(candidates)
        occupancy = Occupancy.new(candidates)
        candidates.select { |candidate| !@policy.fallback?(candidate) || occupancy.alone?(candidate) }
      end
    end
  end
end
