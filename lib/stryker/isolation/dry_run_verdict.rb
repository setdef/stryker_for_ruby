# frozen_string_literal: true

require_relative "dry_run_error"
require_relative "dry_run_reason"
require_relative "error"
require_relative "flight"

module Stryker
  module Isolation
    class DryRunVerdict < Data.define(:dry_run, :messages, :ending)
      UNLANDED = "The dry run's flight never landed, so the dry run found nothing."
      private_constant(:UNLANDED)

      def self.awaited(dry_run)
        # @type var found: Array[DryRunResult]
        found = []
        yield(Flight.new(dry_run) { |messages, ending| found << new(dry_run:, messages:, ending:).result })
        found.first or raise(Error, UNLANDED)
      end

      def result
        found = messages.found
        raise(DryRunError, DryRunReason.new(dry_run, messages, ending).to_s) unless found && passed?

        found
      end

      private def passed?
        !messages.failure && messages.ended? && ending.clean?
      end

      # @dynamic dry_run, messages, ending
    end
  end
end
