# frozen_string_literal: true

require "prism"
require_relative "span"

module Stryker
  class Instrumenter
    module MutatedNode
      CONTAINERS = [Prism::ProgramNode].freeze
      private_constant(:CONTAINERS)

      def self.of(plain, node)
        at(plain.result.value, Span.grown(node.location, plain.growth_within(node)))
      end

      def self.at(tree, span)
        tree.breadth_first_search { |node| !CONTAINERS.include?(node.class) && span.same?(node.location) }
      end
      private_class_method(:at)
    end
  end
end
