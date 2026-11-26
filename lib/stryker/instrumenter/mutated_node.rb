# frozen_string_literal: true

require "prism"
require_relative "error"
require_relative "span"

module Stryker
  class Instrumenter
    module MutatedNode
      CONTAINERS = [Prism::ProgramNode, Prism::StatementsNode].freeze
      private_constant(:CONTAINERS)

      def self.of(plain, node)
        span = Span.grown(node.location, plain.growth_within(node))
        result = plain.result
        found = at(result.value, span)
        return found if found && result.success?

        raise(Error, "Mutant #{plain.mutant.id} doesn't parse as one node where its switch goes.")
      end

      def self.at(tree, span)
        tree.breadth_first_search { |node| !CONTAINERS.include?(node.class) && span.same?(node.location) }
      end
      private_class_method(:at)
    end
  end
end
