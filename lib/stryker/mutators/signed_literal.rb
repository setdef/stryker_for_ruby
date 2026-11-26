# frozen_string_literal: true

require "prism"
require_relative "../edit"

module Stryker
  module Mutators
    class SignedLiteral < Data.define(:node)
      def self.of(node, parent)
        # The number inside -2i has the sign too, and the edit of -2i covers it.
        return if parent.is_a?(Prism::ImaginaryNode)

        case node
        when Prism::IntegerNode, Prism::FloatNode, Prism::RationalNode, Prism::ImaginaryNode
          # A zero of the other sign equals it, except that a float's sign shows
          # in 1 / -0.0, which only a test that divides by the value sees.
          new(node:) if node.slice.start_with?("-", "+") && !node.value.zero?
        end
      end

      def edit
        Edit.over(node.location, negative? ? unsigned : "-#{unsigned}")
      end

      private def negative?
        node.slice.start_with?("-")
      end

      private def unsigned
        node.slice.delete_prefix("-").delete_prefix("+")
      end

      # @dynamic node
    end
  end
end
