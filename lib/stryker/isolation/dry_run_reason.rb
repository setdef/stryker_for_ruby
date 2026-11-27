# frozen_string_literal: true

require_relative "dry_run_ending"

module Stryker
  module Isolation
    class DryRunReason < Data.define(:dry_run, :messages, :ending)
      FAILED = "The dry run failed: %<test>s failed with no mutant active, so it can't judge a mutant. " \
        "Fix the test, or leave it out.\n%<message>s"
      TIMEOUT = "The dry run's tests took more than %<minutes>s minutes, the limit that dryRunTimeoutMinutes sets. " \
        "Raise dryRunTimeoutMinutes for a test suite that takes longer to run once."
      private_constant(:FAILED, :TIMEOUT)

      def to_s
        failed || past_limit || DryRunEnding.new(messages, ending).to_s
      end

      private def failed
        failure = messages.failure or return
        format(FAILED, test: failure.test.id, message: failure.failure_message)
      end

      private def past_limit
        format(TIMEOUT, minutes: dry_run.timeout_ms / 60_000.0) if ending.timed_out && messages.tests_started?
      end

      # @dynamic dry_run, messages, ending
    end
  end
end
