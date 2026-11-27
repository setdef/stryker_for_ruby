# frozen_string_literal: true

module Stryker
  module Reporters
    class StatusCounts
      def initialize
        @by_status = Hash.new(0)
      end

      def add(status)
        @by_status[status] += 1
      end

      def tested
        @by_status.values.sum
      end

      def survived
        @by_status["Survived"]
      end

      def timed_out
        @by_status["Timeout"]
      end
    end
  end
end
