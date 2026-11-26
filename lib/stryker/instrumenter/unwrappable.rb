# frozen_string_literal: true

require "prism"
require_relative "conditional"

module Stryker
  class Instrumenter
    module Unwrappable
      COMPOUNDS = [
        Prism::AliasMethodNode,
        Prism::InterpolatedMatchLastLineNode,
        Prism::InterpolatedRegularExpressionNode,
        Prism::InterpolatedStringNode,
        Prism::InterpolatedSymbolNode,
        Prism::InterpolatedXStringNode,
        Prism::UndefNode,
      ].freeze
      private_constant(:COMPOUNDS)

      def self.at?(node, parent, grandparent)
        part?(node, parent) || label?(node) || bare_array?(node) || matched_with_captures?(node, parent, grandparent) ||
          Conditional.at?(node, parent)
      end

      def self.part?(node, parent)
        # A word of %w[] or %i[], an elsif, which Prism makes an IfNode inside
        # its if, a part of an interpolated or adjacent string, and a name in
        # alias or undef are each of a kind that holds a switch elsewhere, but
        # not text that can stand in parentheses where it is.
        case parent
        when Prism::ArrayNode then parent.opening_loc&.slice.to_s.start_with?("%")
        when Prism::IfNode then !parent.predicate.equal?(node)
        else COMPOUNDS.include?(parent.class)
        end
      end
      private_class_method(:part?)

      def self.label?(node)
        return false unless node.is_a?(Prism::SymbolNode)

        node.closing_loc&.slice.to_s.end_with?(":")
      end
      private_class_method(:label?)

      def self.matched_with_captures?(node, parent, grandparent)
        # A regexp literal with named captures on the left of =~ declares its
        # captures as local variables only while it stays a literal there.
        parent.is_a?(Prism::MatchWriteNode) ||
          (node.is_a?(Prism::RegularExpressionNode) && grandparent.is_a?(Prism::MatchWriteNode))
      end
      private_class_method(:matched_with_captures?)

      def self.bare_array?(node)
        node.is_a?(Prism::ArrayNode) && !node.opening_loc
      end
      private_class_method(:bare_array?)
    end
  end
end
