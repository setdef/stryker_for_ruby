# frozen_string_literal: true

require "prism"
require_relative "../edit"
require_relative "construction"

module Stryker
  module Mutators
    class ArrayConstructor < Data.define(:call, :message_loc)
      def self.of(node)
        return unless node.is_a?(Prism::CallNode) && Construction.of?(node, :Array)

        # A call of new written with a dot or a scope operator always has its
        # name. Prism types it as optional, and a call built by hand can lack
        # it, so the check is also for the type.
        message_loc = node.message_loc
        new(call: node, message_loc:) if message_loc && given_something?(node)
      end

      def edit
        # The call without its arguments and block: the receiver, the
        # operator, and the name, as written.
        span = call.location
        Edit.over(span, call.slice.byteslice(0, message_loc.end_offset - span.start_offset).to_s)
      end

      def self.given_something?(call)
        # Array.new and Array.new([]) both give an empty array, so dropping the
        # arguments of either makes no difference.
        given = call.arguments&.arguments || []
        !(given.empty? || (given.one? && empty_array?(given.first)))
      end
      private_class_method(:given_something?)

      def self.empty_array?(node)
        node.is_a?(Prism::ArrayNode) && node.elements.empty?
      end
      private_class_method(:empty_array?)

      # @dynamic call, message_loc
    end
  end
end
