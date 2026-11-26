# frozen_string_literal: true

require_relative "junction"
require_relative "script_guard"

module Stryker
  module Mutators
    module LogicalOperator
      SWAPS = { "&&": "||", "||": "&&", and: "or", or: "and" }.freeze
      private_constant(:SWAPS)

      def self.name
        "LogicalOperator"
      end

      def self.edits(node, _ancestors)
        return [] if ScriptGuard.decided_by?(node)

        [Junction.of(node)&.edit(SWAPS)].compact
      end
    end
  end
end
