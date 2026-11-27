# frozen_string_literal: true

require_relative "progress_line"

module Stryker
  module Reporters
    class ProgressLog
      INTERVAL_SECONDS = 10
      private_constant(:INTERVAL_SECONDS)

      def initialize(io, ink)
        @io = io
        @ink = ink
        @last = 0
      end

      def update(tally, elapsed)
        return if elapsed - @last < INTERVAL_SECONDS

        @io.write("#{ProgressLine.new(tally, elapsed:, ink: @ink).plain}\n")
        @last = elapsed
      end

      def finish
        nil
      end
    end
  end
end
