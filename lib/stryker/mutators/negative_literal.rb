# frozen_string_literal: true

require "prism"
require_relative "../edit"

module Stryker
  module Mutators
    class NegativeLiteral < Data.define(:node)
      def self.of(node, parent)
        # The number inside -2i has the sign too, and the edit of -2i covers it.
        return if parent.is_a?(Prism::ImaginaryNode)

        case node
        when Prism::IntegerNode, Prism::FloatNode, Prism::RationalNode, Prism::ImaginaryNode
          # An integer, rational, or imaginary zero equals its negative. A float
          # zero differs only in 1 / -0.0, which only a test that divides by the
          # value sees, so its survivor isn't worth acting on.
          new(node:) if node.slice.start_with?("-") && !node.value.zero?
        end
      end

      def edit
        Edit.over(node.location, node.slice.delete_prefix("-"))
      end

      # @dynamic node
    end
  end
end
