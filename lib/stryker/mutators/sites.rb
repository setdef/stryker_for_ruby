# frozen_string_literal: true

require "prism"

module Stryker
  module Mutators
    module Sites
      LOADERS = %i[require require_relative load autoload].freeze
      private_constant(:LOADERS)

      def self.children(node)
        return [] if type_signature?(node)

        loaded = loader_arguments(node)
        node.compact_child_nodes.reject { |child| child.equal?(loaded) }
      end

      def self.type_signature?(node)
        node.is_a?(Prism::CallNode) && node.name == :sig && !node.receiver && node.block.is_a?(Prism::BlockNode)
      end

      def self.loader?(call)
        name = call.name
        # autoload is also a method of a module, so it keeps its rule with a
        # receiver. The other three are Kernel methods that a receiver would
        # make some other call.
        LOADERS.include?(name) && (name == :autoload || !call.receiver)
      end

      def self.loader_arguments(node)
        node.arguments if node.is_a?(Prism::CallNode) && loader?(node)
      end
      private_class_method(:loader_arguments)
    end
  end
end
