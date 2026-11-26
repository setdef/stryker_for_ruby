# frozen_string_literal: true

require "prism"

module Stryker
  class Instrumenter
    module Holder
      NOT_EXPRESSIONS = [
        Prism::ArgumentsNode,
        Prism::AssocNode,
        Prism::AssocSplatNode,
        Prism::BlockArgumentNode,
        Prism::BlockLocalVariableNode,
        Prism::BlockNode,
        Prism::BlockParameterNode,
        Prism::BlockParametersNode,
        Prism::CallTargetNode,
        Prism::ClassVariableTargetNode,
        Prism::ConstantPathTargetNode,
        Prism::ConstantTargetNode,
        Prism::ElseNode,
        Prism::EmbeddedStatementsNode,
        Prism::EmbeddedVariableNode,
        Prism::EnsureNode,
        Prism::FlipFlopNode,
        Prism::ForwardingParameterNode,
        Prism::GlobalVariableTargetNode,
        Prism::ImplicitNode,
        Prism::ImplicitRestNode,
        Prism::InNode,
        Prism::IndexTargetNode,
        Prism::InstanceVariableTargetNode,
        Prism::ItParametersNode,
        Prism::KeywordHashNode,
        Prism::KeywordRestParameterNode,
        Prism::LocalVariableTargetNode,
        Prism::MultiTargetNode,
        Prism::NoKeywordsParameterNode,
        Prism::NumberedParametersNode,
        Prism::OptionalKeywordParameterNode,
        Prism::OptionalParameterNode,
        Prism::ParametersNode,
        Prism::PreExecutionNode,
        Prism::ProgramNode,
        Prism::RequiredKeywordParameterNode,
        Prism::RequiredParameterNode,
        Prism::RescueNode,
        Prism::RestParameterNode,
        Prism::SplatNode,
        Prism::StatementsNode,
        Prism::WhenNode,
      ].freeze
      INTERPOLATED = [
        Prism::InterpolatedMatchLastLineNode,
        Prism::InterpolatedRegularExpressionNode,
        Prism::InterpolatedStringNode,
        Prism::InterpolatedSymbolNode,
        Prism::InterpolatedXStringNode,
      ].freeze
      private_constant(:INTERPOLATED, :NOT_EXPRESSIONS)

      def self.holds?(node, parent, grandparent)
        !NOT_EXPRESSIONS.include?(node.class) && !INTERPOLATED.include?(parent.class) && !label?(node) &&
          !matched_with_captures?(node, parent, grandparent) && !body_run_before_test?(node, grandparent) &&
          !bare_array?(node)
      end

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

      def self.body_run_before_test?(node, grandparent)
        case grandparent
        when Prism::WhileNode, Prism::UntilNode then node.is_a?(Prism::BeginNode) && grandparent.begin_modifier?
        else false
        end
      end
      private_class_method(:body_run_before_test?)

      def self.bare_array?(node)
        node.is_a?(Prism::ArrayNode) && !node.opening_loc
      end
      private_class_method(:bare_array?)
    end
  end
end
