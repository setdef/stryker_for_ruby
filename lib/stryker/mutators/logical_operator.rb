# frozen_string_literal: true

require_relative "junction"

module Stryker
  module Mutators
    module LogicalOperator
      SWAPS = { "&&": "||", "||": "&&", and: "or", or: "and" }.freeze
      private_constant(:SWAPS)

      def self.name
        "LogicalOperator"
      end

      def self.edits(node, _ancestors)
        [Junction.of(node)&.edit(SWAPS)].compact
      end
    end
  end
end
