# frozen_string_literal: true

require_relative "json_value"
require_relative "status"
require_relative "test"

module Stryker
  class TestResult < Data.define(:test, :status, :failure_message, :duration_ms)
    include JsonValue

    STATUSES = %w[passed failed skipped].freeze
    public_constant(:STATUSES)

    def self.readers
      { test: Test.method(:from_h).to_proc }
    end

    def initialize(status:, **)
      Status.check(status, STATUSES, "test")
      super
    end

    # @dynamic test, status, failure_message, duration_ms
  end
end
