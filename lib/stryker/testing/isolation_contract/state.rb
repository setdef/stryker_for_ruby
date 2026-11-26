# frozen_string_literal: true

require_relative "sample"

module Stryker
  module Testing
    module IsolationContract
      module State
        include Sample

        def test_a_run_that_changes_state_leaves_the_next_run_unchanged
          # One at a time, so the run that changes the state ends before the
          # runs that check it start.
          statuses = with_sample { |sample| isolated(sample, sample.state_runs).transform_values(&:status) }
          ids = [SampleSuite::CHANGER, *SampleSuite::CHECKS.values]

          assert_equal(ids.to_h { |id| [id, "Survived"] }, statuses)
        end
      end
    end
  end
end
