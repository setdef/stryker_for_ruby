# frozen_string_literal: true

require "prism"
require_relative "conditional"
require_relative "unparsable"

module Stryker
  class Instrumenter
    module Unwrappable
      def self.at?(node, parent, grandparent)
        Unparsable.at?(node, parent) || matched_with_captures?(node, parent, grandparent) ||
          Conditional.at?(node, parent)
      end

      def self.matched_with_captures?(node, parent, grandparent)
        # A regexp literal with named captures on the left of =~ declares its
        # captures as local variables only while it stays a literal there.
        parent.is_a?(Prism::MatchWriteNode) ||
          (node.is_a?(Prism::RegularExpressionNode) && grandparent.is_a?(Prism::MatchWriteNode))
      end
      private_class_method(:matched_with_captures?)
    end
  end
end
