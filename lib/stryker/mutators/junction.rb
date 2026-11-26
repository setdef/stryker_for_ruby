# frozen_string_literal: true

require "prism"
require_relative "../edit"
require_relative "node_text"

module Stryker
  module Mutators
    class Junction < Data.define(:node)
      def self.of(node)
        new(node:) if node.is_a?(Prism::AndNode) || node.is_a?(Prism::OrNode)
      end

      def edit(swaps)
        Edit.over(node.location, NodeText.replacing(node, [*grouping, swap(swaps)]))
      end

      private def swap(swaps)
        [node.operator_loc, swaps[node.operator.to_sym]]
      end

      private def grouping
        # In a || b || c, the left operand is an ||, and when the last || becomes
        # &&, a || b && c would group the other way. && binds tighter than ||,
        # so the left operand needs parentheses.
        left = node.left
        return [] unless node.operator == "||" && left.is_a?(Prism::OrNode)

        [NodeText.parenthesized(left)]
      end

      # @dynamic node
    end
  end
end
