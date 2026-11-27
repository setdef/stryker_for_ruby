# frozen_string_literal: true

require "prism"
require_relative "../edit"

module Stryker
  module Mutators
    module ObjectLiteral
      def self.name
        "ObjectLiteral"
      end

      def self.edits(node, _ancestors)
        # A keyword hash, as in Discount.new(rate: 0.1), is a KeywordHashNode:
        # emptying it changes the call's arguments. An empty hash has nothing
        # to empty.
        return [] unless node.is_a?(Prism::HashNode) && !node.elements.empty?

        [Edit.over(node.location, "{}")]
      end
    end
  end
end
