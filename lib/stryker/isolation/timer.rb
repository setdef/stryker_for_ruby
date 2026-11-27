# frozen_string_literal: true

module Stryker
  module Isolation
    class Timer
      START_SECONDS = 300
      public_constant(:START_SECONDS)

      def self.now
        # Monotonic, so a change to the system clock during a run changes no
        # time limit.
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def initialize(milliseconds, start_seconds = START_SECONDS)
        @milliseconds = milliseconds
        @started = Timer.now
        @deadline = @started + start_seconds
        @testing = false
      end

      def tests_started
        return if @testing

        # The run's limit covers its tests, so the time a process takes to
        # start and load them counts against the fixed limit for starting
        # only (#85).
        @testing = true
        @deadline = Timer.now + (@milliseconds / 1000.0)
        nil
      end

      def testing?
        @testing
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
