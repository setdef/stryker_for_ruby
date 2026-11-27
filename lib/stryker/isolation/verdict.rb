# frozen_string_literal: true

require_relative "../mutant_result"
require_relative "runtime_error_reason"

module Stryker
  module Isolation
    class Verdict
      def self.call(run, messages, ending)
        new(run, messages, ending).result
      end

      def initialize(run, messages, ending)
        @run = run
        @messages = messages
        @ending = ending
        @failure = messages.results.find { |result| result.status == "failed" }
      end

      def result
        status, status_reason = judged
        MutantResult.new(mutant: @run.mutant, status:, status_reason:, **details)
      end

      private def judged
        # A failed test kills the mutant whatever the process did after it
        # said so: crashed, exited with an error, or ran past its time.
        failure = @failure
        return ["Killed", failure.failure_message] if failure
        return ["Timeout", "Timeout of #{@run.timeout_ms} ms exceeded."] if timed_out?
        return ["Survived", nil] if survived?

        ["RuntimeError", RuntimeErrorReason.new(@run, @messages, @ending).to_s]
      end

      private def details
        {
          killed_by:,
          covered_by: @run.covered_by,
          tests_completed: @messages.results.size,
          duration_ms: @ending.duration_ms,
          static: @run.static,
        }
      end

      private def killed_by
        failure = @failure
        failure ? [failure.test.id] : []
      end

      private def timed_out?
        # A run that no test started never times out, because no test judged
        # its mutant (#85).
        @ending.timed_out && @messages.tests_started?
      end

      private def survived?
        @messages.ended? && @ending.clean? && @messages.results.size == @run.test_ids.size
      end
    end
  end
end
