# frozen_string_literal: true

require_relative "sample"

module Stryker
  module Testing
    module IsolationContract
      module State
        include Sample

        def test_a_run_that_changes_state_leaves_the_next_run_unchanged
          statuses = with_sample { |sample| changed_then_checked(sample).transform_values(&:status) }
          ids = [SampleSuite::CHANGER, *SampleSuite::CHECKS.values]

          assert_equal(ids.to_h { |id| [id, "Survived"] }, statuses)
        end

        private def changed_then_checked(sample)
          # The checks only read, so they go together once the run that changes
          # the state has ended.
          checks = sample.checking_runs
          isolated(sample, [sample.changing_run]).merge(isolated(sample, checks, concurrency: checks.size))
        end
      end
    end
  end
end
