# frozen_string_literal: true

require "prism"
require_relative "../edit"
require_relative "array_constructor"

module Stryker
  module Mutators
    module ArrayDeclaration
      EMPTIED = "[]"
      private_constant(:EMPTIED)

      FILLER = '["Stryker was here"]'
      private_constant(:FILLER)

      def self.name
        "ArrayDeclaration"
      end

      def self.edits(node, _ancestors)
        case node
        when Prism::ArrayNode then literal(node)
        else [ArrayConstructor.of(node)&.edit].compact
        end
      end

      def self.literal(node)
        # An array written with no brackets, as in a, b = 1, 2, reads as a
        # different assignment when emptied, not as an emptied array.
        return [] unless node.opening_loc

        [Edit.over(node.location, node.elements.empty? ? FILLER : EMPTIED)]
      end
      private_class_method(:literal)
    end
  end
end
