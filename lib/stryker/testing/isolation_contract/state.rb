# frozen_string_literal: true

require_relative "sample"

module Stryker
  module Testing
    module IsolationContract
      module State
        include Sample

        def test_a_run_that_changes_state_leaves_the_next_run_unchanged
          # One session for both batches, so that what the run that changes the
          # state leaves in the process that starts the runs, such as a fork
          # parent, reaches the checks too.
          statuses = with_sample do |sample|
            isolated(sample, *sample.state_batches, concurrency: SampleSuite::CHECKS.size).transform_values(&:status)
          end
          ids = [SampleSuite::CHANGER, *SampleSuite::CHECKS.values]

          assert_equal(ids.to_h { |id| [id, "Survived"] }, statuses)
        end
      end
    end
  end
end
