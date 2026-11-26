# frozen_string_literal: true

require_relative "sample"

module Stryker
  module Testing
    module IsolationContract
      module Crashes
        include Sample

        def test_a_process_that_exits_after_a_failed_test_still_kills_the_mutant
          assert_killed_by(:fails_then_exits)
        end

        def test_a_process_that_a_signal_ends_after_a_failed_test_still_kills_the_mutant
          assert_killed_by(:fails_then_signals)
        end

        def test_a_process_that_exits_before_any_result_is_a_runtime_error
          assert_runtime_error(%i[passes exits], 1, "exited with status 3")
        end

        def test_a_runtime_errors_reason_ends_with_the_end_of_standard_error
          ending = "while #{SampleProject.id(:exits)} ran.\nleaving with status 3"
          assert_runtime_error(%i[passes exits], 1, ending)
        end

        def test_a_test_that_calls_exit_is_a_runtime_error
          assert_runtime_error(%i[calls_exit passes], 0, "SystemExit")
        end

        private def assert_killed_by(name)
          result = isolated_one(SampleProject::HARMLESS, name).to_h

          assert_equal({ status: "Killed", killed_by: [SampleProject.id(name)] }, result.slice(:status, :killed_by))
        end

        private def assert_runtime_error(names, completed, reason)
          result = isolated_one(SampleProject::HARMLESS, *names).to_h

          assert_equal({ status: "RuntimeError", tests_completed: completed }, result.slice(:status, :tests_completed))
          assert_includes(result[:status_reason], reason)
        end
      end
    end
  end
end
