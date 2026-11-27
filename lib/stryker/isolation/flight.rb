# frozen_string_literal: true

require_relative "ending"
require_relative "error"
require_relative "messages"
require_relative "process_group"

module Stryker
  module Isolation
    class Flight
      KINDS = %w[forked message exited].freeze
      public_constant(:KINDS)

      def initialize(run, judge)
        @run = run
        @judge = judge
        @pid = nil
        @objects = []
      end

      def receive(object)
        kind, value = object.first
        return verdict(value) if kind == "exited"

        record(kind, value)
        nil
      end

      def kill
        pid = @pid
        ProcessGroup.kill(pid) if pid
        nil
      end

      private def record(kind, value)
        case kind
        when "forked" then @pid = Integer(value.to_s, 10)
        when "message" then @objects << value
        else raise(Error, "The fork parent wrote #{kind.inspect} about the run #{about}.")
        end
      end

      private def verdict(ending)
        raise(Error, "The fork parent wrote no ending for the run #{about}.") unless ending.is_a?(Hash)

        @judge.call(@run, Messages.new(@objects), Ending.from_h(ending))
      end

      private def about
        JSON.generate(@run.relay_key)
      end
    end
  end
end
