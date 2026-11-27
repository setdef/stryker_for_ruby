# frozen_string_literal: true

require "prism"
require_relative "../edit"
require_relative "method_swaps"
require_relative "node_text"

module Stryker
  module Mutators
    module MethodExpression
      REMOVALS = %i[
        sort
        sort!
        sort_by
        sort_by!
        reverse
        reverse!
        uniq
        uniq!
        compact
        compact!
        flatten
        flatten!
        strip
        strip!
        chomp
        chomp!
      ].freeze
      private_constant(:REMOVALS)

      def self.name
        "MethodExpression"
      end

      def self.edits(node, _ancestors)
        # The method is known by its name alone, because the instrumenter can't
        # know the receiver's class.
        return [] unless node.is_a?(Prism::CallNode)

        receiver = node.receiver
        receiver ? [swapped(node), removed(node, receiver)].compact : []
      end

      def self.swapped(call)
        name = MethodSwaps.for(call.name)
        message = call.message_loc
        Edit.over(call.location, NodeText.replacing(call, [[message, name.to_s]])) if name && message
      end
      private_class_method(:swapped)

      def self.removed(call, receiver)
        Edit.over(call.location, receiver.slice) if REMOVALS.include?(call.name)
      end
      private_class_method(:removed)
    end
  end
end
