# frozen_string_literal: true

require_relative "operand"
require_relative "operation"

module Stryker
  module Mutators
    class Comparison < Operation
      PROGRAM_NAMES = %w[$0 $PROGRAM_NAME].freeze
      private_constant(:PROGRAM_NAMES)

      def swapped
        # Operands with the same text swap into the original. A heredoc's body
        # follows its opener, in the order of the openers, so a swap gives each
        # opener the other's body, or leaves a body that has no opener.
        return if receiver.slice == argument.slice || holds_heredoc?

        Edit.over(call.location, NodeText.replacing(call, operand_swap))
      end

      def script_check?
        texts = [receiver, argument].map(&:slice)
        operator == :== && texts.include?("__FILE__") && texts.intersect?(PROGRAM_NAMES)
      end

      private def holds_heredoc?
        [receiver, argument].any? { |operand| Operand.holds_heredoc?(operand) }
      end

      private def operand_swap
        [[receiver.location, argument.slice], [argument.location, receiver.slice]]
      end

      # @dynamic self.of, self.edits
    end
  end
end
