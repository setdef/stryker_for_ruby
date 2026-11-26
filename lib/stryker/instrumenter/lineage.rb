# frozen_string_literal: true

require_relative "context"
require_relative "holder"

module Stryker
  class Instrumenter
    class Lineage < Data.define(:node, :parent, :grandparent, :context)
      def self.root(tree)
        new(node: tree, parent: nil, grandparent: nil, context: :free)
      end

      def descend(child)
        Lineage.new(node: child, parent: node, grandparent: parent, context: Context.of_child(self, child))
      end

      def holds?
        context == :free && Holder.holds?(node, parent, grandparent)
      end

      # @dynamic node, parent, grandparent, context
    end
  end
end
