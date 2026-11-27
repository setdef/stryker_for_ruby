# frozen_string_literal: true

require "prism"
require_relative "node_text"
require_relative "strings"

module Stryker
  module Mutators
    class AssignmentWrite < Data.define(:node, :operator_loc, :value)
      LOGICAL = %w[||= &&=].freeze
      private_constant(:LOGICAL)

      def self.of(node)
        # Prism has a node for each target and each kind of assignment, such as
        # LocalVariableOperatorWriteNode and IndexOrWriteNode, and no class
        # that they share. Only an operator assignment's node writes its
        # operator as one of these fields.
        return unless node.type.match?(/_(operator|or|and)_write_node\z/)

        parts = node.deconstruct_keys(%i[binary_operator_loc operator_loc value])
        new(node:, operator_loc: parts[:binary_operator_loc] || parts[:operator_loc], value: parts[:value])
      end

      def operator
        operator_loc.slice
      end

      def string_value?
        # A string appended, repeated, or formatted, such as name += "x", raises
        # NoMethodError for the other operator. ||= and &&= keep their pairs,
        # which swap one for the other whatever the right side holds.
        !LOGICAL.include?(operator) && Strings.literal?(value)
      end

      def with_operator(replacement)
        NodeText.replacing(node, [[operator_loc, replacement]])
      end

      # @dynamic node, operator_loc, value
    end
  end
end
