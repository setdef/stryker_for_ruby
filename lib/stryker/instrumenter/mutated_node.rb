# frozen_string_literal: true

require "prism"

module Stryker
  class Instrumenter
    module MutatedNode
      CONTAINERS = [Prism::ProgramNode].freeze
      private_constant(:CONTAINERS)

      def self.at(tree, span)
        tree.breadth_first_search { |node| !CONTAINERS.include?(node.class) && span.same?(node.location) }
      end
    end
  end
end
