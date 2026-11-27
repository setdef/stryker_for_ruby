# frozen_string_literal: true

require_relative "ending"
require_relative "error"
require_relative "messages"
require_relative "process_group"
require_relative "verdict"

module Stryker
  module Isolation
    class Flight
      KINDS = %w[forked message exited].freeze
      public_constant(:KINDS)

      attr_reader :run

      def self.judged(run)
        new(run) { |messages, ending| yield(Verdict.new(run, messages, ending).result) }
      end

      def initialize(run, &landing)
        @run = run
        @landing = landing
        @pid = nil
        @objects = []
      end

      def receive(object)
        kind, value = object.first
        return ending(value) if kind == "exited"

        record(kind, value)
        nil
      end

      def land(ending)
        @landing.call(Messages.new(@objects), ending)
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

      private def ending(value)
        raise(Error, "The fork parent wrote no ending for the run #{about}.") unless value.is_a?(Hash)

        Ending.from_h(value)
      end

      private def about
        JSON.generate(@run.relay_key)
      end

      # @dynamic run
    end
  end
end
