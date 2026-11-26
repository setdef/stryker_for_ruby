# frozen_string_literal: true

require "prism"
require_relative "error"
require_relative "span"

module Stryker
  class Instrumenter
    module MutatedNode
      CONTAINERS = [Prism::ProgramNode, Prism::StatementsNode].freeze
      private_constant(:CONTAINERS)

      def self.of(source, mutant, node)
        span = Span.grown(node.location, mutant.growth)
        result = Prism.parse(mutant.edit(source).force_encoding(source.encoding))
        found = at(result.value, span)
        return found if found && result.success?

        raise(Error, "Mutant #{mutant.id} doesn't parse as one node where its switch goes.")
      end

      def self.at(tree, span)
        tree.breadth_first_search { |node| !CONTAINERS.include?(node.class) && span.same?(node.location) }
      end
      private_class_method(:at)
    end
  end
end
