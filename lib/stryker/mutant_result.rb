# frozen_string_literal: true

require_relative "json_value"
require_relative "mutant"
require_relative "status"

module Stryker
  class MutantResult < Data.define(
    :mutant,
    :status,
    :status_reason,
    :killed_by,
    :covered_by,
    :tests_completed,
    :duration_ms,
    :static
  )
    include JsonValue

    STATUSES = %w[Killed Survived NoCoverage CompileError RuntimeError Timeout Ignored].freeze
    public_constant(:STATUSES)

    def self.unrun(mutant, status, reason = nil)
      new(
        mutant:,
        status:,
        status_reason: reason,
        killed_by: [],
        covered_by: [],
        tests_completed: nil,
        duration_ms: nil,
        static: false
      )
    end

    def self.readers
      { mutant: Mutant.method(:from_h).to_proc }
    end

    def initialize(status:, **)
      Status.check(status, STATUSES, "mutant")
      super
    end

    # @dynamic mutant, status, status_reason, killed_by, covered_by, tests_completed, duration_ms, static
  end
end
