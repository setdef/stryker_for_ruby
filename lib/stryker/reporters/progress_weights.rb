# frozen_string_literal: true

require_relative "../plan/time_limit"

module Stryker
  module Reporters
    class ProgressWeights
      def self.none
        new({}, 0.0)
      end

      def self.of(dry_run)
        new(dry_run.results.to_h { |result| [result.test.id, result.duration_ms] }, Plan::TimeLimit.overhead(dry_run))
      end

      def initialize(durations, overhead)
        @durations = durations
        @overhead = overhead
      end

      def of(run)
        net = run.test_ids.sum(0.0) { |id| @durations.fetch(id, 0.0) }
        run.static ? net + @overhead : net
      end
    end
  end
end
