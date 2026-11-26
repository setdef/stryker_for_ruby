# frozen_string_literal: true

require "prism"
require_relative "comparison"
require_relative "prefix"

module Stryker
  module Mutators
    module ScriptGuard
      def self.check?(node)
        Comparison.of(unparenthesized(node), %i[==])&.script_check? || false
      end

      def self.decided_by?(node)
        deciders(node).any? { |operand| check?(operand) }
      end

      def self.deciders(node)
        case node
        when Prism::AndNode, Prism::OrNode then [node.left, node.right]
        when Prism::IfNode, Prism::UnlessNode, Prism::WhileNode, Prism::UntilNode then [node.predicate]
        else negated(node)
        end
      end
      private_class_method(:deciders)

      def self.negated(node)
        operand = Prefix.of(node, %i[!])&.receiver
        operand ? [operand] : []
      end
      private_class_method(:negated)

      def self.unparenthesized(node)
        return node unless node.is_a?(Prism::ParenthesesNode)

        # The statements of the parentheses, which are one for (a) and more or
        # fewer for (a; b) and ().
        statements = node.compact_child_nodes.flat_map(&:compact_child_nodes)
        statements.one? ? unparenthesized(statements.first) : node
      end
      private_class_method(:unparenthesized)
    end
  end
end
