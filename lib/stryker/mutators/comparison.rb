# frozen_string_literal: true

require_relative "operation"

module Stryker
  module Mutators
    class Comparison < Operation
      PROGRAM_NAMES = %w[$0 $PROGRAM_NAME].freeze
      private_constant(:PROGRAM_NAMES)

      def swapped
        # Operands with the same text swap into the original.
        return if receiver.slice == argument.slice

        Edit.over(call.location, NodeText.replacing(call, operand_swap))
      end

      def script_check?
        texts = [receiver, argument].map(&:slice)
        operator == :== && texts.include?("__FILE__") && texts.intersect?(PROGRAM_NAMES)
      end

      private def operand_swap
        [[receiver.location, argument.slice], [argument.location, receiver.slice]]
      end

      # @dynamic self.of, self.edits
    end
  end
end
