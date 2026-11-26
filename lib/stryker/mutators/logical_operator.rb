# frozen_string_literal: true

require_relative "junction"

module Stryker
  module Mutators
    class LogicalOperator
      SWAPS = { "&&": "||", "||": "&&", and: "or", or: "and" }.freeze
      private_constant(:SWAPS)

      def name
        "LogicalOperator"
      end

      def edits(node, _ancestors)
        [Junction.of(node)&.edit(swaps)].compact
      end

      private def swaps
        SWAPS
      end
    end
  end
end
