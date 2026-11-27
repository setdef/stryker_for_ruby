# frozen_string_literal: true

require "prism"
require_relative "../edit"

module Stryker
  module Mutators
    module BlockStatement
      OWNERS = [
        Prism::DefNode,
        Prism::BlockNode,
        Prism::LambdaNode,
        Prism::IfNode,
        Prism::UnlessNode,
        Prism::ElseNode,
        Prism::WhenNode,
        Prism::InNode,
        Prism::WhileNode,
        Prism::UntilNode,
        Prism::ForNode,
        Prism::BeginNode,
        Prism::RescueNode,
        Prism::EnsureNode,
      ].freeze
      private_constant(:OWNERS)

      def self.name
        "BlockStatement"
      end

      def self.edits(node, ancestors)
        return [] unless body?(node, ancestors)

        [Edit.over(node.location, "nil")]
      end

      def self.body?(node, ancestors)
        # A class, module, or singleton class body isn't one, and neither is
        # the top level of a file: emptying one takes every method in it, so
        # every test that touches it fails and the survivor shows nothing new.
        node.is_a?(Prism::StatementsNode) && OWNERS.include?(ancestors.last.class) && !nil_only?(node.body) &&
          !guard_pattern?(ancestors)
      end
      private_class_method(:body?)

      def self.guard_pattern?(ancestors)
        # Prism holds the pattern of `in pattern if condition` as the
        # statements of an if, which is the pattern of the in clause.
        clause, guard = ancestors.last(2)
        clause.is_a?(Prism::InNode) && clause.pattern.equal?(guard)
      end
      private_class_method(:guard_pattern?)

      def self.nil_only?(statements)
        # A Ruby body that is empty returns nil, so a body that is only nil
        # would give the same program.
        statements.one? && statements.first.is_a?(Prism::NilNode)
      end
      private_class_method(:nil_only?)
    end
  end
end
