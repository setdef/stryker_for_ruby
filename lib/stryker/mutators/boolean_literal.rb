# frozen_string_literal: true

require "prism"
require_relative "prefix"
require_relative "respelling"

module Stryker
  module Mutators
    class BooleanLiteral
      RESPELLINGS = {
        Prism::TrueNode => "false",
        Prism::FalseNode => "true",
        Prism::UnlessNode => "if",
        Prism::UntilNode => "while",
      }.freeze
      private_constant(:RESPELLINGS)

      NEGATIONS = { "!": [nil] }.freeze
      private_constant(:NEGATIONS)

      def name
        "BooleanLiteral"
      end

      def edits(node, _ancestors)
        Respelling.edits(node, respellings) + Prefix.edits(node, negations) { false }
      end

      private def respellings
        RESPELLINGS
      end

      private def negations
        NEGATIONS
      end
    end
  end
end
