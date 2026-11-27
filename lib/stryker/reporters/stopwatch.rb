# frozen_string_literal: true

module Stryker
  module Reporters
    class Stopwatch
      def initialize(clock)
        @clock = clock
        @started = clock.call
      end

      def restart
        @started = @clock.call
      end

      def elapsed
        @clock.call - @started
      end
    end
  end
end
