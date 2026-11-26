# frozen_string_literal: true

require_relative "operation"

module Stryker
  module Mutators
    class ArithmeticOperator
      PAIRS = { "+": %w[-], "-": %w[+], "*": %w[/], "/": %w[*], "%": %w[*] }.freeze
      private_constant(:PAIRS)

      def name
        "ArithmeticOperator"
      end

      def edits(node, _ancestors)
        Operation.edits(node, pairs, &:string_operand?)
      end

      private def pairs
        PAIRS
      end
    end
  end
end
