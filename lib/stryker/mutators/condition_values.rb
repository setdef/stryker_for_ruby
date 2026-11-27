# frozen_string_literal: true

require "prism"

module Stryker
  module Mutators
    module ConditionValues
      BOTH = %w[true false].freeze
      private_constant(:BOTH)

      LOOPS = { Prism::WhileNode => %w[false], Prism::UntilNode => %w[true] }.freeze
      private_constant(:LOOPS)

      def self.of(place)
        parent = place.parent
        return unless predicate(parent).equal?(place.child)

        # A loop's condition becomes only the value that ends the loop at once.
        # The other value never ends it, so the run would end in a Timeout and
        # cost its whole time limit.
        LOOPS[parent.class] || BOTH
      end

      def self.predicate(node)
        case node
        when Prism::IfNode, Prism::UnlessNode, Prism::WhileNode, Prism::UntilNode then node.predicate
        end
      end
      private_class_method(:predicate)
    end
  end
end
