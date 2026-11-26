# frozen_string_literal: true

require_relative "negative_literal"
require_relative "prefix"

module Stryker
  module Mutators
    class UnaryOperator
      PREFIXES = { "-@": [nil], "+@": ["-"], "~": [nil] }.freeze
      private_constant(:PREFIXES)

      def name
        "UnaryOperator"
      end

      def edits(node, ancestors)
        Prefix.edits(node, prefixes, &:string_sign?) + [NegativeLiteral.of(node, ancestors.last)&.edit].compact
      end

      private def prefixes
        # nil drops the operator, which gives the same value as +a on a number
        # and works on any receiver, where +a raises NoMethodError for a class
        # that has no +@.
        PREFIXES
      end
    end
  end
end
