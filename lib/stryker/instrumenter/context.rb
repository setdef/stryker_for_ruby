# frozen_string_literal: true

require "prism"

module Stryker
  class Instrumenter
    module Context
      def self.of_child(lineage, child)
        case lineage.context
        when :closed then :closed
        when :pattern then leaves_pattern?(lineage, child) ? :free : :pattern
        else free(lineage.node, child)
        end
      end

      def self.free(node, child)
        return :closed if child.is_a?(Prism::PreExecutionNode) || node.is_a?(Prism::DefinedNode)

        case node
        when Prism::InNode, Prism::MatchPredicateNode, Prism::MatchRequiredNode
          node.pattern.equal?(child) ? :pattern : :free
        else :free
        end
      end
      private_class_method(:free)

      def self.leaves_pattern?(lineage, child)
        node = lineage.node
        case node
        when Prism::PinnedExpressionNode then node.expression.equal?(child)
        when Prism::IfNode, Prism::UnlessNode then guard?(lineage.parent) && node.predicate.equal?(child)
        else false
        end
      end
      private_class_method(:leaves_pattern?)

      def self.guard?(parent)
        parent.is_a?(Prism::InNode)
      end
      private_class_method(:guard?)
    end
  end
end
