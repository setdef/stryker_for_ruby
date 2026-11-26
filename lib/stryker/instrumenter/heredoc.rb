# frozen_string_literal: true

require "prism"

module Stryker
  class Instrumenter
    module Heredoc
      def self.kept?(node, mutant)
        heredocs_at(node).any? { |heredoc| !mutant.covers?(heredoc.location) }
      end

      def self.heredocs_at(node)
        case node
        when Prism::StringNode, Prism::InterpolatedStringNode, Prism::XStringNode, Prism::InterpolatedXStringNode
          node.heredoc? ? [node] : []
        else []
        end
      end

      def self.in(node)
        [*heredocs_at(node), *node.compact_child_nodes.flat_map { |child| self.in(child) }]
      end
    end
  end
end
