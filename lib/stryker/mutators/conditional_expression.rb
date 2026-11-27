# frozen_string_literal: true

require "prism"
require_relative "../edit"
require_relative "condition_values"
require_relative "operand_values"
require_relative "operator_call"
require_relative "place"
require_relative "script_guard"

module Stryker
  module Mutators
    module ConditionalExpression
      COMPARISONS = %i[== != < <= > >=].freeze
      private_constant(:COMPARISONS)

      ANYWHERE = %w[true false].freeze
      private_constant(:ANYWHERE)

      def self.name
        "ConditionalExpression"
      end

      def self.edits(node, ancestors)
        replacements(node, ancestors).map { |text| Edit.over(node.location, text) }
      end

      def self.replacements(node, ancestors)
        return [] if skipped?(node)

        place = Place.of(node, ancestors)
        ConditionValues.of(place) || (operator?(node) ? OperandValues.of(place) || ANYWHERE : [])
      end
      private_class_method(:replacements)

      def self.skipped?(node)
        literal?(node) || parenthesized?(node) || ScriptGuard.check?(node) || ScriptGuard.decided_by?(node)
      end
      private_class_method(:skipped?)

      def self.literal?(node)
        # BooleanLiteral makes the opposite of true and false, and the other
        # one of the two mutants here would be the original.
        node.is_a?(Prism::TrueNode) || node.is_a?(Prism::FalseNode)
      end
      private_class_method(:literal?)

      def self.parenthesized?(node)
        # The statement inside stands where the parentheses stand, and gets the
        # mutant, so a mutant of the whole would be a second one for it.
        statements = node.is_a?(Prism::ParenthesesNode) && node.body
        statements.is_a?(Prism::StatementsNode) && statements.body.one?
      end
      private_class_method(:parenthesized?)

      def self.operator?(node)
        node.is_a?(Prism::AndNode) || node.is_a?(Prism::OrNode) || OperatorCall.of(node, COMPARISONS).is_a?(Prism::CallNode)
      end
      private_class_method(:operator?)
    end
  end
end
