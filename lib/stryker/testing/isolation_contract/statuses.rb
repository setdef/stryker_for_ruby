# frozen_string_literal: true

require_relative "sample"

module Stryker
  module Testing
    module IsolationContract
      module Statuses
        include Sample

        MANY = [SampleLibrary::KILLING, 10, 11, 12].freeze
        private_constant(:MANY)

        def test_a_failed_test_kills_the_mutant
          result = isolated_one(SampleLibrary::KILLING, :value).to_h
          expected = { status: "Killed", killed_by: [SampleProject.id(:value)], tests_completed: 1 }

          assert_equal(expected, result.slice(:status, :killed_by, :tests_completed))
          assert_includes(result[:status_reason], "Expected: :original")
        end

        def test_a_run_whose_tests_all_pass_survives
          result = isolated_one(SampleProject::HARMLESS, :value, :passes).to_h
          expected = { status: "Survived", status_reason: nil, killed_by: Array(nil), tests_completed: 2 }

          assert_equal(expected, result.slice(:status, :status_reason, :killed_by, :tests_completed))
        end

        def test_a_result_is_covered_by_the_tests_its_run_lists_as_covering_it
          result = isolated_one(SampleProject::HARMLESS, :value, :passes)

          assert_equal([SampleProject.id(:passes)], result.covered_by)
        end

        def test_a_run_stops_at_its_first_failed_test
          result = isolated_one(SampleLibrary::KILLING, :passes, :value, :hangs).to_h

          assert_equal({ status: "Killed", tests_completed: 2 }, result.slice(:status, :tests_completed))
        end

        def test_a_run_past_its_time_limit_times_out
          # Only a test that hangs, so the verdict is the same whether the
          # limit ends while the process is starting or while the test hangs.
          result = isolated_one(SampleProject::HARMLESS, :hangs, timeout_ms: 500).to_h
          expected = { status: "Timeout", status_reason: "Timeout of 500 ms exceeded." }

          assert_equal(expected, result.slice(:status, :status_reason))
        end

        def test_each_run_gives_one_result_with_its_mutant_and_time
          results = with_sample { |sample| isolated(sample, sample.runs(MANY, :passes), concurrency: 2) }

          assert_equal(
            MANY.to_h { |id| [id, true] },
            results.transform_values do |result|
              Float(result.duration_ms).positive?
            end
          )
        end
      end
    end
  end
end
