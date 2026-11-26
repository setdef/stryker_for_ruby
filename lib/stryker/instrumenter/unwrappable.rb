# frozen_string_literal: true

require "prism"
require_relative "conditional"
require_relative "unparsable"

module Stryker
  class Instrumenter
    module Unwrappable
      def self.at?(node, parent, grandparent)
        Unparsable.at?(node, parent) || matched_with_captures?(node, grandparent) ||
          self_receiver?(node, parent) || loop_body?(node, grandparent) || Conditional.at?(node, parent)
      end

      def self.matched_with_captures?(node, grandparent)
        # A regexp literal with named captures on the left of =~ declares its
        # captures as local variables only while it stays a literal there.
        node.is_a?(Prism::RegularExpressionNode) && grandparent.is_a?(Prism::MatchWriteNode)
      end
      private_class_method(:matched_with_captures?)

      def self.self_receiver?(node, parent)
        # Ruby calls a private method through a receiver only when the
        # receiver is the keyword self itself, and not an expression whose
        # value is self.
        return false unless node.is_a?(Prism::SelfNode)

        case parent
        when Prism::CallAndWriteNode, Prism::CallNode, Prism::CallOperatorWriteNode, Prism::CallOrWriteNode,
             Prism::CallTargetNode, Prism::IndexAndWriteNode, Prism::IndexOperatorWriteNode, Prism::IndexOrWriteNode,
             Prism::IndexTargetNode

          parent.receiver.equal?(node)
        else false
        end
      end
      private_class_method(:self_receiver?)

      def self.loop_body?(node, grandparent)
        # Ruby runs the body of begin ... end while once before it tests the
        # condition, and a wrapped begin ... end makes an ordinary modifier
        # loop, which tests first.
        return false unless node.is_a?(Prism::BeginNode)

        case grandparent
        when Prism::UntilNode, Prism::WhileNode then grandparent.begin_modifier?
        else false
        end
      end
      private_class_method(:loop_body?)
    end
  end
end
