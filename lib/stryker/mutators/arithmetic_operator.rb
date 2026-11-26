# frozen_string_literal: true

require_relative "operation"

module Stryker
  module Mutators
    module ArithmeticOperator
      PAIRS = { "+": %w[-], "-": %w[+], "*": %w[/], "/": %w[*], "%": %w[*] }.freeze
      private_constant(:PAIRS)

      def self.name
        "ArithmeticOperator"
      end

      def self.edits(node, _ancestors)
        Operation.edits(node, PAIRS, &:string_operand?)
      end
    end
  end
end
