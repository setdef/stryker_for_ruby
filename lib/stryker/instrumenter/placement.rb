# frozen_string_literal: true

require_relative "lineage"
require_relative "span"

module Stryker
  class Instrumenter
    class Placement
      def self.node_for(tree, mutant, bodies)
        new(mutant, bodies).holder_in(tree)
      end

      def initialize(mutant, bodies)
        @mutant = mutant
        @openers = bodies.filter_map { |heredoc, body| Span.of(heredoc.location) if mutant.inside?(body) }
      end

      def holder_in(tree)
        holder_below(Lineage.root(tree), nil)
      end

      private def holder_below(lineage, holder)
        node = lineage.node
        holder = node if lineage.holds? && covers?(node)
        child = child_covering(node)
        child ? holder_below(lineage.descend(child), holder) : holder
      end

      private def child_covering(node)
        node.compact_child_nodes.find { |child| covers?(child) }
      end

      private def covers?(node)
        # An edit inside a heredoc's body lies outside the location of the
        # heredoc's opener and of every node around it, so a node holds such
        # an edit when its location holds the opener.
        location = node.location
        @mutant.inside?(location) || @openers.any? { |opener| opener.within?(location) }
      end
    end
  end
end
