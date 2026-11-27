# frozen_string_literal: true

require "prism"

module Stryker
  module Mutators
    class SafeNavigation < Data.define(:receiver, :operator_loc)
      NEVER_NIL = [
        Prism::SelfNode,
        Prism::TrueNode,
        Prism::FalseNode,
        Prism::IntegerNode,
        Prism::FloatNode,
        Prism::RationalNode,
        Prism::ImaginaryNode,
        Prism::StringNode,
        Prism::InterpolatedStringNode,
        Prism::XStringNode,
        Prism::InterpolatedXStringNode,
        Prism::SymbolNode,
        Prism::InterpolatedSymbolNode,
        Prism::RegularExpressionNode,
        Prism::InterpolatedRegularExpressionNode,
        Prism::ArrayNode,
        Prism::HashNode,
        Prism::LambdaNode,
        Prism::SourceFileNode,
        Prism::SourceLineNode,
        Prism::SourceEncodingNode,
      ].freeze
      private_constant(:NEVER_NIL)

      def self.of(node)
        case node
        when Prism::CallNode, Prism::CallOperatorWriteNode, Prism::CallOrWriteNode, Prism::CallAndWriteNode
          operator_loc = node.call_operator_loc
          new(receiver: node.receiver, operator_loc:) if node.safe_navigation? && operator_loc
        end
      end

      def nil_possible?
        !NEVER_NIL.include?(receiver.class)
      end

      # @dynamic receiver, operator_loc
    end
  end
end
