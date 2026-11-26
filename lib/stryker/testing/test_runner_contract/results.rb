# frozen_string_literal: true

require_relative "sample"

module Stryker
  module Testing
    module TestRunnerContract
      module Results
        include Sample

        def test_a_passing_test_passes_with_no_message_and_its_time
          result = run_roles(:passes, bail: false).first
          duration = result.duration_ms

          assert_equal(["passed", nil], [result.status, result.failure_message])
          assert_kind_of(Float, duration)
          assert_operator(duration, :>=, 0)
        end

        def test_a_failed_assertion_fails_with_its_message
          assert_fails_with(:fails, FAILURE)
        end

        def test_an_error_raised_outside_an_assertion_fails_with_its_message
          assert_fails_with(:errors, ERROR)
        end

        def test_a_skipped_test_is_skipped_with_no_message
          result = run_roles(:skips, bail: false).first

          assert_equal(["skipped", nil], [result.status, result.failure_message])
        end

        private def assert_fails_with(role, message)
          result = run_roles(role, bail: false).first

          assert_equal("failed", result.status)
          assert_includes(result.failure_message, message)
        end
      end
    end
  end
end
