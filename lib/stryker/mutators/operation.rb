# frozen_string_literal: true

require "prism"
require_relative "operator_site"
require_relative "strings"

module Stryker
  module Mutators
    class Operation < Data.define(:call, :receiver, :argument, :operator_loc)
      include OperatorSite

      def self.written(call)
        # A call with a name like an operator's and no dot always has these
        # parts. Prism types each as optional, and a call built by hand can
        # lack one, so the check is also for the types.
        receiver = call.receiver
        argument = call.arguments&.arguments&.first
        operator_loc = call.message_loc
        new(call:, receiver:, argument:, operator_loc:) if receiver && argument && operator_loc
      end

      def string_operand?
        [receiver, argument].any? { |operand| Strings.literal?(operand) }
      end

      # @dynamic call, receiver, argument, operator_loc
    end
  end
end
