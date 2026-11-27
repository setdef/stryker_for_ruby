# frozen_string_literal: true

require_relative "dry_run_error"
require_relative "dry_run_reason"
require_relative "error"

module Stryker
  module Isolation
    class DryRunVerdict < Data.define(:dry_run, :messages, :ending)
      UNLANDED = "The dry run never landed, so it found nothing."
      private_constant(:UNLANDED)

      def self.awaited(dry_run)
        # @type var found: Array[DryRunResult]
        found = []
        yield(-> (messages, ending) { found << new(dry_run:, messages:, ending:).result })
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
