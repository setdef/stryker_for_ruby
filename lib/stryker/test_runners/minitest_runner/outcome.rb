# frozen_string_literal: true

require_relative "../../test_result"
require_relative "scrubbing_filter"

module Stryker
  module TestRunners
    class MinitestRunner
      class Outcome
        PASSED = "."
        SKIPPED = "S"
        private_constant(:PASSED, :SKIPPED)

        def self.now
          Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond)
        end

        def initialize(name)
          @name = name
          @started = Outcome.now
          @failures = []
          @code = nil
        end

        def prerecord(_klass, _name)
          nil
        end

        def record(result)
          code = result.result_code
          # Minitest matches each line of a backtrace with a regexp, and raises
          # for a line with the path of a file whose name isn't valid UTF-8.
          @failures << ScrubbingFilter.around { result.to_s } unless [PASSED, SKIPPED].include?(code)
          @code = code if result.name == @name
          nil
        end

        def passed?
          true
        end

        def result(test)
          TestResult.new(test:, status:, failure_message:, duration_ms: Outcome.now - @started)
        end

        private def status
          return "failed" unless @failures.empty?

          (@code == PASSED) ? "passed" : "skipped"
        end

        private def failure_message
          @failures.join("\n") unless @failures.empty?
        end
      end
    end
  end
end
