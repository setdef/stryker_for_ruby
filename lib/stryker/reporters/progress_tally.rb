# frozen_string_literal: true

require_relative "duration_text"
require_relative "status_counts"

module Stryker
  module Reporters
    class ProgressTally
      def initialize(weights)
        @weights = weights.values.sum.zero? ? weights.transform_values { 1.0 } : weights
        @total = @weights.values.sum(0.0)
        @done = 0.0
        @counts = StatusCounts.new
      end

      def mutants
        @weights.size
      end

      def tested
        @counts.tested
      end

      def survived
        @counts.survived
      end

      def timed_out
        @counts.timed_out
      end

      def record(result)
        weight = @weights[result.mutant.id] or return
        @done += weight
        @counts.add(result.status)
        weight
      end

      def fraction
        (tested == mutants) ? 1.0 : @done / @total
      end

      def percent
        (fraction * 100).floor
      end

      def times(elapsed)
        left = seconds_left(elapsed)
        "elapsed: #{DurationText.of(elapsed.floor)}, remaining: #{left ? DurationText.of(left) : 'n/a'}"
      end

      def seconds_left(elapsed)
        return unless @done.positive?

        left = ((elapsed.floor / @done) * (@total - @done)).floor
        left if left.positive?
      end
    end
  end
end
