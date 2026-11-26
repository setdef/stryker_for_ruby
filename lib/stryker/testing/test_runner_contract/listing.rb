# frozen_string_literal: true

require_relative "sample"

module Stryker
  module Testing
    module TestRunnerContract
      module Listing
        include Sample

        def test_load_tests_returns_each_sample_test_once
          ids = runner_under_test.load_tests.map(&:id)

          assert_empty(sample_test_ids.values - ids)
          assert_equal(ids.uniq, ids)
        end

        def test_load_tests_runs_no_test
          runner_under_test.load_tests

          assert_empty(SampleRuns.take)
        end

        def test_each_result_holds_the_test_that_load_tests_returned
          tests = run_roles(*ROLES, bail: false).map(&:test)

          assert_empty(tests - runner_under_test.load_tests)
        end
      end
    end
  end
end
