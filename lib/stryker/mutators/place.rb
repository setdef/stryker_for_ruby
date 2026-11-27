# frozen_string_literal: true

require "prism"

module Stryker
  module Mutators
    class Place < Data.define(:parent, :child, :grandparent)
      def self.of(node, ancestors)
        child, chain = unwrapped(node, ancestors)
        grandparent, parent = [nil, *chain].last(2)
        new(parent:, child:, grandparent:)
      end

      def self.unwrapped(child, chain)
        # Parentheses around one statement are not a place of their own: the
        # statement stands where the parentheses stand.
        *outer, parentheses, statements = chain
        if parentheses.is_a?(Prism::ParenthesesNode) && one_statement?(statements)
          unwrapped(parentheses, outer)
        else
          [child, chain]
        end
      end
      private_class_method(:unwrapped)

      def self.one_statement?(statements)
        statements.is_a?(Prism::StatementsNode) && statements.body.one?
      end
      private_class_method(:one_statement?)

      # @dynamic parent, child, grandparent
    end
  end
end
