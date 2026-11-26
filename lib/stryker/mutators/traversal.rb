# frozen_string_literal: true

require_relative "sites"

module Stryker
  module Mutators
    class Traversal
      def initialize(tree)
        @tree = tree
        @ancestors = []
      end

      def each(&)
        visit(@tree, &)
      end

      private def visit(node, &)
        yield(node, @ancestors)
        @ancestors.push(node)
        Sites.children(node).each { |child| visit(child, &) }
        @ancestors.pop
      end
    end
  end
end
