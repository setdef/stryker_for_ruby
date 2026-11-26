# frozen_string_literal: true

require "prism"
require_relative "prefix"
require_relative "respelling"
require_relative "script_guard"

module Stryker
  module Mutators
    module BooleanLiteral
      RESPELLINGS = {
        Prism::TrueNode => "false",
        Prism::FalseNode => "true",
        Prism::UnlessNode => "if",
        Prism::UntilNode => "while",
      }.freeze
      private_constant(:RESPELLINGS)

      NEGATIONS = { "!": [nil] }.freeze
      private_constant(:NEGATIONS)

      def self.name
        "BooleanLiteral"
      end

      def self.edits(node, _ancestors)
        return [] if ScriptGuard.decided_by?(node)

        Respelling.edits(node, RESPELLINGS) + Prefix.edits(node, NEGATIONS) { false }
      end
    end
  end
end
