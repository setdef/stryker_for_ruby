# frozen_string_literal: true

require_relative "../edit"
require_relative "assignment_write"

module Stryker
  module Mutators
    module AssignmentOperator
      SWAPS = {
        "+=": "-=",
        "-=": "+=",
        "*=": "/=",
        "/=": "*=",
        "%=": "*=",
        "<<=": ">>=",
        ">>=": "<<=",
        "&=": "|=",
        "|=": "&=",
        "||=": "&&=",
        "&&=": "||=",
      }.freeze
      private_constant(:SWAPS)

      def self.name
        "AssignmentOperator"
      end

      def self.edits(node, _ancestors)
        write = AssignmentWrite.of(node)
        swap = SWAPS[write.operator.to_sym] if write
        return [] unless write && swap && !write.string_value?

        [Edit.over(node.location, write.with_operator(swap))]
      end
    end
  end
end
