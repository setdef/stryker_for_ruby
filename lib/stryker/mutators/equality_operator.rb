# frozen_string_literal: true

require_relative "comparison"

module Stryker
  module Mutators
    module EqualityOperator
      PAIRS = { "<": %w[<= >=], "<=": %w[< >], ">": %w[>= <=], ">=": %w[> <], "==": %w[!=], "!=": %w[==] }.freeze
      private_constant(:PAIRS)

      def self.name
        "EqualityOperator"
      end

      def self.edits(node, _ancestors)
        Comparison.edits(node, PAIRS, &:script_check?) + [Comparison.of(node, %i[<=>])&.swapped].compact
      end
    end
  end
end
