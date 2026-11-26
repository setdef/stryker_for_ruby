# frozen_string_literal: true

require_relative "../json_value"

module Stryker
  module Isolation
    class Ending < Data.define(:exit_status, :signal, :timed_out, :duration_ms, :errors)
      include JsonValue

      def self.of(status, timed_out:, duration_ms:)
        number = status.termsig
        new(
          exit_status: status.exitstatus,
          signal: number && Signal.signame(number),
          timed_out:,
          duration_ms:,
          errors: ""
        )
      end

      def clean?
        exit_status.eql?(0)
      end

      def description
        signal ? "was ended by signal #{signal}" : "exited with status #{exit_status}"
      end

      # @dynamic exit_status, signal, timed_out, duration_ms, errors
    end
  end
end
