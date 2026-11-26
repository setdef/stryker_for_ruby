# frozen_string_literal: true

require_relative "buckets"
require_relative "process_collector"

module Stryker
  module Runtime
    class Recorder
      def initialize(process_collector = ProcessCollector.new)
        @lock = Mutex.new
        @buckets = Buckets.new
        @process_collector = process_collector
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

      def drain
        @lock.synchronize { drain_held }
      end

      def test_started(test)
        # The check comes first, so that a refused start drains nothing. A
        # hit sent from another Ractor before this test started lands in the
        # static bucket, not in this test's.
        @lock.synchronize do
          @buckets.check_start(test)
          drain_held
          @buckets.start(test)
        end
      end

      def test_finished(_result)
        @lock.synchronize do
          @buckets.check_finish
          drain_held
          @buckets.finish
        end
      end

      def record(ids)
        return if @buckets.recorded?(ids)

        @lock.synchronize { @buckets.record(ids) }
      end

      def load_began(path)
        @lock.synchronize { @buckets.load_began(path) }
      end

      private def drain_held
        @process_collector.drain.each { |message| @buckets.receive(message) }
        nil
      end
    end
  end
end
