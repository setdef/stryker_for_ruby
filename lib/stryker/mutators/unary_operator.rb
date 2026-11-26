# frozen_string_literal: true

require_relative "prefix"
require_relative "signed_literal"

module Stryker
  module Mutators
    module UnaryOperator
      PREFIXES = { "-@": [nil], "+@": ["-"], "~": [nil] }.freeze
      private_constant(:PREFIXES)

      def self.name
        "UnaryOperator"
      end

      def self.edits(node, ancestors)
        # nil in PREFIXES drops the operator, which gives the same value as +a
        # on a number and works on any receiver, where +a raises NoMethodError
        # for a class that has no +@.
        Prefix.edits(node, PREFIXES, &:string_sign?) + [SignedLiteral.of(node, ancestors.last)&.edit].compact
      end
    end
  end
end
