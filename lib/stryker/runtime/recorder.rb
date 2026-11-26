# frozen_string_literal: true

require_relative "test_run"

module Stryker
  module Runtime
    class Recorder
      def initialize
        @static = Set.new
        @runs = {}
        @current = nil
        @collector = nil
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

      def collect_from(collector)
        @collector = collector
        nil
      end

      def test_started(test)
        # A hit sent from another Ractor before this test started lands in
        # the static bucket, not in this test's.
        drain
        @current = @runs[test] = TestRun.new
        nil
      end

      def test_finished(_result)
        drain
        @current = nil
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

      private def drain
        collector = @collector
        return unless collector

        collector.drain.each { |message| receive(message) }
      end
    end
  end
end
