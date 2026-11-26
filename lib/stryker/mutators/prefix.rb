# frozen_string_literal: true

require "prism"
require_relative "operator_site"
require_relative "strings"

module Stryker
  module Mutators
    class Prefix < Data.define(:call, :receiver, :operator_loc)
      include OperatorSite

      def self.written(call)
        # A call with a prefix operator's name and no dot always has a receiver
        # and an operator. Prism types each as optional, and a call built by
        # hand can lack one, so the check is also for the types.
        receiver = call.receiver
        operator_loc = call.message_loc
        new(call:, receiver:, operator_loc:) if receiver && operator_loc
      end

      def string_sign?
        %i[-@ +@].include?(operator) && Strings.literal?(receiver)
      end

      # @dynamic call, receiver, operator_loc
    end
  end
end
