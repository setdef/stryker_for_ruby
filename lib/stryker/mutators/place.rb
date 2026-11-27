# frozen_string_literal: true

require "prism"

module Stryker
  module Mutators
    class Place < Data.define(:parent, :child)
      def self.of(node, ancestors)
        # Parentheses around one statement are not a place of their own: the
        # statement stands where the parentheses stand.
        child = node
        chain = ancestors
        while parenthesized?(chain)
          child = chain[-2]
          chain = chain.take(chain.size - 2)
        end
        new(parent: chain.last, child:)
      end

      def self.parenthesized?(chain)
        statements = chain.last
        statements.is_a?(Prism::StatementsNode) && chain[-2].is_a?(Prism::ParenthesesNode) && statements.body.one?
      end
      private_class_method(:parenthesized?)

      # @dynamic parent, child
    end
  end
end
