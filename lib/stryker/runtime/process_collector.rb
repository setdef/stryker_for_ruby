# frozen_string_literal: true

require_relative "collector"

module Stryker
  module Runtime
    class ProcessCollector
      SECOND_DRY_RUN = "The isolation adapter readied a dry run twice in one process, so the hits sent to the " \
        "first collector would be lost."
      private_constant(:SECOND_DRY_RUN)

      def initialize
        @collector = nil
        @dry_run = nil
      end

      def use(collector)
        @collector = collector
        nil
      end

      def dry_run_started(collector, pid = Process.pid)
        # A forked child inherits this object, and readies its own dry run.
        raise(SECOND_DRY_RUN) if @dry_run == pid

        @dry_run = pid
        use(collector)
      end

      def unstarted
        @collector&.unstarted
      end

      def drain
        @collector&.drain || []
      end
    end
  end
end
