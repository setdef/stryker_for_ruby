# frozen_string_literal: true

module Stryker
  class Instrumenter
    class ParseDeadline
      def initialize(seconds)
        @at = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
      end

      def left
        [@at - Process.clock_gettime(Process::CLOCK_MONOTONIC), 0.0].max
      end
    end
  end
end
