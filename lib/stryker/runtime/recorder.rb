# frozen_string_literal: true

require_relative "buckets"

module Stryker
  module Runtime
    class Recorder
      SECOND_DRY_RUN = "The isolation adapter readied a dry run twice in one process, so the hits sent to the " \
        "first collector would be lost."
      private_constant(:SECOND_DRY_RUN)

      def initialize
        @lock = Mutex.new
        @buckets = Buckets.new
        @collector = nil
        @dry_run = nil
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

      def dry_run_started(collector, pid = Process.pid)
        # A forked child inherits the recorder, and readies its own dry run.
        raise(SECOND_DRY_RUN) if @dry_run == pid

        @dry_run = pid
        collect_from(collector)
      end

      def unstarted_collector
        collector = @collector
        return unless collector

        collector.unstarted
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
        message.is_a?(String) ? load_began(message) : record(message)
      end

      def record(ids)
        # A hit whose mutants are all in the current bucket, with no stack
        # check due, would change nothing, so it returns before the lock.
        # Under the GVL, Set#include? never sees another thread's change half
        # made.
        return if @buckets.recorded?(ids)

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
