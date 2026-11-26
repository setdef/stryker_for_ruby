# frozen_string_literal: true

require_relative "sample"

module Stryker
  module Testing
    module TestRunnerContract
      module Bail
        include Sample

        def test_bail_stops_after_the_first_failed_assertion
          results = run_roles(:passes, :fails, :skips, bail: true)

          assert_equal(%i[passes fails], SampleRuns.take)
          assert_equal(%w[passed failed], results.map(&:status))
        end

        def test_bail_stops_after_an_error_raised_outside_an_assertion
          results = run_roles(:errors, :passes, bail: true)

          assert_equal([:errors], SampleRuns.take)
          assert_equal(%w[failed], results.map(&:status))
        end

        def test_bail_runs_on_past_a_skipped_test
          run_roles(:skips, :passes, bail: true)

          assert_equal(%i[skips passes], SampleRuns.take)
        end

        def test_without_bail_every_test_runs_after_a_failure
          results = run_roles(:fails, :errors, :passes, bail: false)

          assert_equal(%i[fails errors passes], SampleRuns.take)
          assert_equal(%w[failed failed passed], results.map(&:status))
        end
      end
    end
  end
end
