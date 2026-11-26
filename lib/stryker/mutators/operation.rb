# frozen_string_literal: true

require "prism"
require_relative "../edit"
require_relative "node_text"
require_relative "strings"

module Stryker
  module Mutators
    class Operation < Data.define(:call, :receiver, :argument, :operator_loc)
      def self.of(node, names)
        return unless node.is_a?(Prism::CallNode) && names.include?(node.name) && !node.call_operator_loc

        written(node)
      end

      def self.edits(node, pairs, &)
        Array(of(node, pairs.keys)&.edits(pairs, &))
      end

      def edits(pairs)
        return [] if yield(self)

        Array(pairs[operator]).map { |replacement| with_operator(replacement) }
      end

      def operator
        call.name
      end

      def string_operand?
        [receiver, argument].any? { |operand| Strings.literal?(operand) }
      end

      def self.written(call)
        # A call with a name like an operator's and no dot always has these
        # parts. Prism types each as optional, and a call built by hand can
        # lack one, so the check is also for the types.
        receiver = call.receiver
        argument = call.arguments&.arguments&.first
        operator_loc = call.message_loc
        new(call:, receiver:, argument:, operator_loc:) if receiver && argument && operator_loc
      end
      private_class_method(:written)

      private def with_operator(replacement)
        Edit.over(call.location, NodeText.replacing(call, [[operator_loc, replacement]]))
      end

      # @dynamic call, receiver, argument, operator_loc
    end
  end
end
