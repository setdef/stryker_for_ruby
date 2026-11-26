# frozen_string_literal: true

require "prism"
require_relative "unwrappable"

module Stryker
  class Instrumenter
    module Holder
      KINDS = [
        Prism::AliasGlobalVariableNode,
        Prism::AliasMethodNode,
        Prism::AndNode,
        Prism::ArrayNode,
        Prism::BeginNode,
        Prism::BreakNode,
        Prism::CallNode,
        Prism::CallOperatorWriteNode,
        Prism::CaseMatchNode,
        Prism::CaseNode,
        Prism::ClassVariableReadNode,
        Prism::ConstantPathNode,
        Prism::ConstantReadNode,
        Prism::ConstantWriteNode,
        Prism::DefNode,
        Prism::DefinedNode,
        Prism::FalseNode,
        Prism::FloatNode,
        Prism::ForwardingSuperNode,
        Prism::GlobalVariableReadNode,
        Prism::HashNode,
        Prism::IfNode,
        Prism::ImaginaryNode,
        Prism::IndexOrWriteNode,
        Prism::InstanceVariableReadNode,
        Prism::IntegerNode,
        Prism::InterpolatedRegularExpressionNode,
        Prism::InterpolatedStringNode,
        Prism::InterpolatedSymbolNode,
        Prism::LambdaNode,
        Prism::LocalVariableAndWriteNode,
        Prism::LocalVariableOperatorWriteNode,
        Prism::LocalVariableOrWriteNode,
        Prism::LocalVariableReadNode,
        Prism::LocalVariableWriteNode,
        Prism::MatchPredicateNode,
        Prism::MatchRequiredNode,
        Prism::MatchWriteNode,
        Prism::MultiWriteNode,
        Prism::NextNode,
        Prism::NilNode,
        Prism::OrNode,
        Prism::ParenthesesNode,
        Prism::PostExecutionNode,
        Prism::RangeNode,
        Prism::RationalNode,
        Prism::RedoNode,
        Prism::RegularExpressionNode,
        Prism::RetryNode,
        Prism::ReturnNode,
        Prism::SelfNode,
        Prism::SourceFileNode,
        Prism::SourceLineNode,
        Prism::StringNode,
        Prism::SuperNode,
        Prism::SymbolNode,
        Prism::TrueNode,
        Prism::UndefNode,
        Prism::UnlessNode,
        Prism::UntilNode,
        Prism::WhileNode,
        Prism::XStringNode,
        Prism::YieldNode,
      ].freeze
      private_constant(:KINDS)

      def self.holds?(node, parent, grandparent)
        KINDS.include?(node.class) && !Unwrappable.at?(node, parent, grandparent)
      end
    end
  end
end
