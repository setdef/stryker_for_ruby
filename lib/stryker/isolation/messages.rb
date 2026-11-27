# frozen_string_literal: true

require_relative "../dry_run_result"
require_relative "../test"
require_relative "../test_result"
require_relative "message"

module Stryker
  module Isolation
    class Messages
      def self.parse(text)
        # A last line with no line break is one the process didn't finish
        # writing.
        new(text.each_line.filter_map { |line| Message.object(line) if line.end_with?("\n") })
      end

      def initialize(objects)
        @values = []
        # The messages up to the first one that isn't a message, because
        # nothing after it can be trusted to be what the run's process wrote.
        objects.all? { |object| kept?(Message.read(object)) }
      end

      def results
        @values.filter_map { |value| value.is_a?(TestResult) && value }
      end

      def failure
        results.find { |result| result.status == "failed" }
      end

      def ended?
        @values.include?(true)
      end

      def tests_started?
        @values.any?(Test)
      end

      def error
        errors = @values.filter_map { |value| value.is_a?(String) && value }
        errors.first
      end

      def load_failure
        failures = @values.filter_map { |value| value.is_a?(LoadFailure) && value }
        failures.first
      end

      def found
        found = @values.filter_map { |value| value.is_a?(DryRunResult) && value }
        found.first
      end

      def unfinished
        tests = @values.filter_map { |value| value.is_a?(Test) && value }
        started = tests.last
        started unless results.any? { |result| result.test == started }
      end

      private def kept?(value)
        return false unless value

        @values << value
        true
      end
    end
  end
end
