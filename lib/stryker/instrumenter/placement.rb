# frozen_string_literal: true

require_relative "lineage"
require_relative "span"

module Stryker
  class Instrumenter
    class Placement
      def self.node_for(tree, mutant)
        new(mutant).holder_in(tree)
      end

      def initialize(mutant)
        @mutant = mutant
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
        children = node.compact_child_nodes
        children.find { |child| covers?(child) } || child_with_heredoc_body_covering(children)
      end

      private def child_with_heredoc_body_covering(children)
        children.find { |child| @mutant.inside?(Span.extent(child)) }
      end

      private def covers?(node)
        @mutant.inside?(node.location)
      end
    end
  end
end
