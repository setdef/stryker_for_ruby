# frozen_string_literal: true

require_relative "comparison"

module Stryker
  module Mutators
    class EqualityOperator
      PAIRS = { "<": %w[<= >=], "<=": %w[< >], ">": %w[>= <=], ">=": %w[> <], "==": %w[!=], "!=": %w[==] }.freeze
      private_constant(:PAIRS)

      def name
        "EqualityOperator"
      end

      def edits(node, _ancestors)
        Comparison.edits(node, pairs, &:script_check?) + [Comparison.of(node, %i[<=>])&.swapped].compact
      end

      private def pairs
        PAIRS
      end
    end
  end
end
