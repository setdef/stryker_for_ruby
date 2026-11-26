# frozen_string_literal: true

require "prism"

module Stryker
  class Instrumenter
    module Conditional
      CONSTRUCTS = [Prism::FlipFlopNode, Prism::InterpolatedMatchLastLineNode, Prism::MatchLastLineNode].freeze
      CONNECTIVES = [Prism::AndNode, Prism::OrNode, Prism::ParenthesesNode, Prism::StatementsNode].freeze
      private_constant(:CONNECTIVES, :CONSTRUCTS)

      def self.at?(node, parent)
        # Ruby matches a regexp literal against $_, reads a range as a
        # flip-flop, and compares an integer endpoint of a flip-flop with $.,
        # only where it stands in a condition, or under !, not, &&, ||, and,
        # or, or parentheses there.
        (node.is_a?(Prism::IntegerNode) && parent.is_a?(Prism::FlipFlopNode)) || holds?(node)
      end

      def self.holds?(node)
        return true if CONSTRUCTS.include?(node.class)

        connective?(node) && node.compact_child_nodes.any? { |child| holds?(child) }
      end
      private_class_method(:holds?)

      def self.connective?(node)
        CONNECTIVES.include?(node.class) || (node.is_a?(Prism::CallNode) && node.name == :!)
      end
      private_class_method(:connective?)
    end
  end
end
