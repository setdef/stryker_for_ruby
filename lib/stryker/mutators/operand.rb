# frozen_string_literal: true

require "prism"

module Stryker
  module Mutators
    module Operand
      def self.holds_heredoc?(node)
        heredoc_opener?(node) || node.compact_child_nodes.any? { |child| holds_heredoc?(child) }
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
    end
  end
end
