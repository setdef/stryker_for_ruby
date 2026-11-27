# frozen_string_literal: true

require_relative "../mutators"
require_relative "directives"
require_relative "occupancy"
require_relative "policy"
require_relative "roster"
require_relative "search"

module Stryker
  module Mutators
    class Walk
      def initialize(file:, result:, mutators: ALL, first_id: 1, policy: Policy.new)
        @search = Search.new(result, file, mutators)
        @policy = policy.reading(Directives.new(file:, result:, names: mutators.map(&:name)))
        @roster = Roster.new(file:, source: result.source.source, first_id:)
      end

      def mutants
        made.mutants
      end

      def ignored
        made.ignored
      end

      def made
        @made ||= @roster.made(chosen(judged(@search.candidates)))
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
