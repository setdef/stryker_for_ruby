# frozen_string_literal: true

require_relative "buckets"

module Stryker
  module Runtime
    class Recorder
      def initialize
        @lock = Mutex.new
        @buckets = Buckets.new
        @collector = nil
      end

      def static
        @lock.synchronize { @buckets.static }
      end

      def tests
        @lock.synchronize { @buckets.tests }
      end

      def loaded
        @lock.synchronize { @buckets.loaded }
      end

      def collect_from(collector)
        @collector = collector
        nil
      end

      def drain
        @lock.synchronize { drain_held }
      end

      def test_started(test)
        # A hit sent from another Ractor before this test started lands in
        # the static bucket, not in this test's.
        @lock.synchronize { @buckets.start(test) { drain_held } }
      end

      def test_finished(_result)
        @lock.synchronize { @buckets.finish { drain_held } }
      end

      def receive(message)
        @lock.synchronize { @buckets.receive(message) }
      end

      def record(ids)
        @lock.synchronize { @buckets.record(ids) }
      end

      def load_began(path)
        @lock.synchronize { @buckets.load_began(path) }
      end

      private def drain_held
        collector = @collector
        return unless collector

        collector.drain.each { |message| @buckets.receive(message) }
        nil
      end
    end
  end
end
