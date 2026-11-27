# frozen_string_literal: true

require_relative "sites"

module Stryker
  module Mutators
    class Occupancy
      def initialize(candidates)
        @counts = Hash.new(0).compare_by_identity
        candidates.each { |candidate| @counts[candidate.site] += 1 }
      end

      def alone?(candidate)
        # The tree, and not the bytes, says what lies inside a site, because a
        # heredoc's body lies after the last byte of the call that holds it.
        site = candidate.site
        @counts[site] == 1 && Sites.children(site).none? { |child| held?(child) }
      end

      private def held?(node)
        @counts[node].positive? || Sites.children(node).any? { |child| held?(child) }
      end
    end
  end
end
