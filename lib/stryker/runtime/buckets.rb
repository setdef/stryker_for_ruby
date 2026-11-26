# frozen_string_literal: true

require_relative "test_run"

module Stryker
  module Runtime
    class Buckets
      NO_TEST_RUNNING = "The test runner adapter reported that a test finished while no test was running, " \
        "so Stryker (for Ruby) can't tell which test a hit belongs to."
      private_constant(:NO_TEST_RUNNING)

      def initialize
        @static = Set.new
        @runs = {}
        @current = nil
      end

      def static
        @static.dup
      end

      def tests
        @runs.transform_values(&:hits)
      end

      def loaded
        @runs.each_value.map(&:loads).reduce(Set.new, :merge)
      end

      def check_start(test)
        # A runner adapter that reports out of order has a fault, and a hit
        # then has no bucket that is certainly its own, so this raises
        # instead of guessing.
        raise(overlap(test)) if @current

        nil
      end

      def start(test)
        @current = (@runs[test] ||= TestRun.new)
        nil
      end

      def check_finish
        raise(NO_TEST_RUNNING) unless @current

        nil
      end

      def finish
        @current = nil
      end

      def recorded?(ids)
        run = @current
        run ? run.recorded?(ids) : ids.all? { |id| @static.include?(id) }
      end

      def receive(message)
        message.is_a?(String) ? load_began(message) : record(message)
      end

      def record(ids)
        run = @current
        run ? run.record(ids, @static) : @static.merge(ids)
        nil
      end

      def load_began(path)
        @current&.load_began(path)
        nil
      end

      private def overlap(test)
        "The test runner adapter reported that #{test.inspect} started while #{@runs.key(@current).inspect} " \
          "was still running, so Stryker (for Ruby) can't tell which test a hit belongs to."
      end
    end
  end
end
