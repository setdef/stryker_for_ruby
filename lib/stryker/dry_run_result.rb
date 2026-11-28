# frozen_string_literal: true

require_relative "json_value"
require_relative "test_result"

module Stryker
  class DryRunResult < Data.define(:results, :buckets, :static_bucket, :files_loaded_in_tests, :duration_ms)
    include JsonValue

    def self.byte_members
      %i[files_loaded_in_tests]
    end

    def self.readers
      { results: method(:read_results).to_proc }
    end

    def self.read_results(values)
      values.map { |value| TestResult.from_h(value) }
    end

    def no_test?
      results.empty?
    end

    # @dynamic results, buckets, static_bucket, files_loaded_in_tests, duration_ms
  end
end
