# frozen_string_literal: true

require "prism"

module Stryker
  module Mutators
    module Operand
      def self.holds_heredoc?(node)
        heredoc_opener?(node) || node.compact_child_nodes.any? { |child| holds_heredoc?(child) }
      end

      def self.left_text(node)
        text = node.slice
        loose?(node) ? "(#{text})" : text
      end

      def self.heredoc_opener?(node)
        case node
        when Prism::StringNode, Prism::InterpolatedStringNode, Prism::XStringNode, Prism::InterpolatedXStringNode
          node.heredoc? == true
        else
          false
        end
      end
      private_class_method(:heredoc_opener?)

      def self.loose?(node)
        case node
        when Prism::DefinedNode then !node.lparen_loc
        when Prism::AndNode, Prism::OrNode then true
        when Prism::CallNode then node.message == "not" && !node.opening_loc
        else false
        end
      end
      private_class_method(:loose?)
    end
  end
end
