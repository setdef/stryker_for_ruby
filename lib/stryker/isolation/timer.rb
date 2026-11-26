# frozen_string_literal: true

module Stryker
  module Isolation
    class Timer
      def self.now
        # Monotonic, so a change to the system clock during a run changes no
        # time limit.
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def initialize(milliseconds)
        @started = Timer.now
        @deadline = @started + (milliseconds / 1000.0)
      end

      def left
        [@deadline - Timer.now, 0.0].max
      end

      def elapsed_ms
        (Timer.now - @started) * 1000
      end
    end
  end
end
