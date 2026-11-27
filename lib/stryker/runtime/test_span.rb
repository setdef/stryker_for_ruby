# frozen_string_literal: true

module Stryker
  module Runtime
    class TestSpan
      def self.now
        Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond)
      end

      def initialize(clock = -> { TestSpan.now })
        @clock = clock
        @started = nil
        @finished = nil
      end

      def started
        @started ||= @clock.call
        nil
      end

      def finished
        @finished = @clock.call
        nil
      end

      def duration_ms
        started = @started
        finished = @finished
        (started && finished) ? finished - started : 0.0
      end
    end
  end
end
