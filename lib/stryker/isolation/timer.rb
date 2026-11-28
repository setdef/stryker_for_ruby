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

      def initialize(milliseconds, start_seconds = START_SECONDS, clock: -> { Timer.now })
        @awaiting_test = [milliseconds]
        @clock = clock
        @started = clock.call
        @deadline = @started + start_seconds
      end

      def tests_started
        milliseconds = @awaiting_test.shift or return

        # The run's limit covers its tests, so the time a process takes to
        # start and load them counts against the fixed limit for starting
        # only (#85).
        @deadline = @clock.call + (milliseconds / 1000.0)
        nil
      end

      def testing?
        @awaiting_test.empty?
      end

      def left
        [@deadline - @clock.call, 0.0].max
      end

      def elapsed_ms
        (@clock.call - @started) * 1000
      end
    end
  end
end
