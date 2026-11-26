# frozen_string_literal: true

require_relative "error"
require_relative "flight"

module Stryker
  module Isolation
    class Flights
      ENDED = "The fork parent ended while %<count>d runs were in flight."
      private_constant(:ENDED)

      def initialize(parent, window)
        @parent = parent
        @window = window
        @flights = {}
      end

      def run(runs)
        waiting = runs.dup
        until waiting.empty? && @flights.empty?
          # At most the window's number of runs are in the parent at once, so
          # the parent forks at most that many children.
          dispatch(waiting.shift) while @flights.size < @window && waiting.any?
          result = receive
          yield(result) if result
        end
      end

      def stop
        @parent.stop
        # A child whose parent was stuck, which the parent couldn't end.
        @flights.each_value(&:kill).clear
        nil
      end

      private def dispatch(run)
        @flights[run.mutant.id] = Flight.new(run)
        @parent.give(run)
      end

      private def receive
        object = @parent.receive or raise(Error, format(ENDED, count: @flights.size))
        id = object.delete("mutant")
        flight(id, object).receive(object)&.tap { @flights.delete(id) }
      end

      private def flight(id, object)
        @flights[id] or raise(Error, "The fork parent wrote #{object.inspect} for mutant #{id.inspect}.")
      end
    end
  end
end
