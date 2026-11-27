# frozen_string_literal: true

require_relative "../dry_run_result"
require_relative "recorder"
require_relative "test_span"

module Stryker
  module Runtime
    class DryRunObserver
      def self.buckets(results, tests)
        results.to_h do |result|
          test = result.test
          [test.id, tests.fetch(test, Set.new).to_a]
        end
      end

      def initialize(observer, recorder = RECORDER, span = TestSpan.new)
        @observer = observer
        @recorder = recorder
        @span = span
        @results = []
      end

      def test_started(test)
        @span.started
        @observer.test_started(test)
        @recorder.test_started(test)
      end

      def test_finished(result)
        # The bucket closes before the result goes out, so that nothing the
        # observer does lands in the test's bucket.
        @recorder.test_finished(result)
        @span.finished
        @results << result
        @observer.test_finished(result)
      end

      def result
        recorder = @recorder
        results = @results.dup
        DryRunResult.new(
          results:,
          buckets: DryRunObserver.buckets(results, recorder.tests),
          static_bucket: recorder.static.to_a,
          files_loaded_in_tests: recorder.loaded.to_a,
          duration_ms: @span.duration_ms
        )
      end
    end
  end
end
