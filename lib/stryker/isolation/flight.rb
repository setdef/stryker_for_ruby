# frozen_string_literal: true

require_relative "ending"
require_relative "error"
require_relative "messages"
require_relative "process_group"
require_relative "verdict"

module Stryker
  module Isolation
    class Flight
      def initialize(run)
        @run = run
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
        else raise(Error, "The fork parent wrote #{kind.inspect} for mutant #{@run.mutant.id}.")
        end
      end

      private def verdict(ending)
        raise(Error, "The fork parent wrote no ending for mutant #{@run.mutant.id}'s run.") unless ending.is_a?(Hash)

        Verdict.new(@run, Messages.new(@objects), Ending.from_h(ending)).result
      end
    end
  end
end
