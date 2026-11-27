# frozen_string_literal: true

require "prism"
require_relative "construction"

module Stryker
  module Mutators
    class StringContext < Data.define(:node, :ancestors)
      INTERPOLATED = [
        Prism::InterpolatedStringNode,
        Prism::InterpolatedXStringNode,
        Prism::InterpolatedSymbolNode,
        Prism::InterpolatedRegularExpressionNode,
        Prism::InterpolatedMatchLastLineNode,
      ].freeze
      private_constant(:INTERPOLATED)

      WORD_ARRAYS = %w[%w %W].freeze
      private_constant(:WORD_ARRAYS)

      def self.word_array?(node)
        node.is_a?(Prism::ArrayNode) && WORD_ARRAYS.any? { |word| node.opening.to_s.start_with?(word) }
      end

      def mutable?
        !(part? || key? || word? || interpolated? || pattern?)
      end

      private def parent
        ancestors.last
      end

      private def part?
        INTERPOLATED.include?(parent.class)
      end

      private def key?
        pair = parent
        pair.is_a?(Prism::AssocNode) && pair.key.equal?(node)
      end

      private def word?
        self.class.word_array?(parent)
      end

      private def interpolated?
        ancestors.any?(Prism::EmbeddedStatementsNode)
      end

      private def pattern?
        node.is_a?(Prism::StringNode) && Construction.first_argument?(node, ancestors, :Regexp)
      end

      # @dynamic node, ancestors
    end
  end
end
