# frozen_string_literal: true

require_relative "context"
require_relative "holder"

module Stryker
  class Instrumenter
    # steep:ignore:start
    class Lineage < Data.define(:node, :parent, :grandparent, :context)
      # steep:ignore:end
      def self.root(tree)
        new(node: tree, parent: nil, grandparent: nil, context: :free)
      end

      def descend(child)
        Lineage.new(node: child, parent: node, grandparent: parent, context: Context.of_child(self, child))
      end

      def holds?
        context == :free && Holder.holds?(node, parent, grandparent)
      end
    end
  end
end
