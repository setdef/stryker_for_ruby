# frozen_string_literal: true

require "prism"
require_relative "../edit"
require_relative "node_text"
require_relative "operator_call"

module Stryker
  module Mutators
    class Prefix < Data.define(:call, :receiver, :operator_loc)
      def self.of(node, names)
        call = OperatorCall.of(node, names)
        written(call) if call
      end

      def self.edits(node, replacements, &)
        Array(of(node, replacements.keys)&.edits(replacements, &))
      end

      def edits(replacements)
        return [] if yield(self)

        Array(replacements[operator]).map { |replacement| replacement ? with_operator(replacement) : dropped }
      end

      def operator
        call.name
      end

      def self.written(call)
        # A call with a prefix operator's name and no dot always has a receiver
        # and an operator. Prism types each as optional, and a call built by
        # hand can lack one, so the check is also for the types.
        receiver = call.receiver
        operator_loc = call.message_loc
        new(call:, receiver:, operator_loc:) if receiver && operator_loc
      end
      private_class_method(:written)

      private def dropped
        Edit.over(call.location, receiver.slice)
      end

      private def with_operator(replacement)
        Edit.over(call.location, NodeText.replacing(call, [[operator_loc, replacement]]))
      end

      # @dynamic call, receiver, operator_loc
    end
  end
end
