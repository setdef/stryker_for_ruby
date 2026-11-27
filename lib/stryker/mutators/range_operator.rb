# frozen_string_literal: true

require "prism"
require_relative "../edit"
require_relative "node_text"

module Stryker
  module Mutators
    module RangeOperator
      def self.name
        "RangeOperator"
      end

      def self.edits(node, _ancestors)
        # An endless range iterates, slices, and tests membership the same way
        # with either operator. A flip-flop is a FlipFlopNode, not a RangeNode.
        return [] unless node.is_a?(Prism::RangeNode) && node.right

        swapped = node.exclude_end? ? ".." : "..."
        [Edit.over(node.location, NodeText.replacing(node, [[node.operator_loc, swapped]]))]
      end
    end
  end
end
