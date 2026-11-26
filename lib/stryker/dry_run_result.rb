# frozen_string_literal: true

require_relative "json_value"
require_relative "test_result"

module Stryker
  class DryRunResult < Data.define(:results, :buckets, :static_bucket, :files_loaded_in_tests)
    include JsonValue

    def self.readers
      { results: method(:read_results).to_proc }
    end

    def self.read_results(values)
      values.map { |value| TestResult.from_h(value) }
    end

    # @dynamic results, buckets, static_bucket, files_loaded_in_tests
  end
end
