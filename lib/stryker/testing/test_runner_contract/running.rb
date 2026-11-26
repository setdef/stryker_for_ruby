# frozen_string_literal: true

require_relative "sample"

module Stryker
  module Testing
    module TestRunnerContract
      module Running
        include Sample

        def test_run_runs_each_chosen_test_once_in_the_order_given
          results = run_roles(:skips, :errors, :passes, bail: false)

          assert_equal(%i[skips errors passes], SampleRuns.take)
          assert_equal(ids(:skips, :errors, :passes), results.map { |result| result.test.id })
        end

        def test_run_runs_no_test_when_given_none
          assert_empty(run_roles(bail: false))
          assert_empty(SampleRuns.take)
        end

        def test_the_observer_hears_each_start_before_the_test_and_each_finish_after_it
          observer = Observer.new
          first, second = chosen = ids(:passes, :fails)
          runner_under_test.run(chosen, bail: false, observer:)
          heard = [[:started, first, 0], [:finished, first, 1], [:started, second, 1], [:finished, second, 2]]

          assert_equal(heard, observer.events)
        end

        def test_run_refuses_an_unknown_id_before_it_runs_any_test
          observer = Observer.new

          assert_raises(ArgumentError) { loaded_runner.run([*ids(:passes), "No such test"], bail: false, observer:) }
          assert_empty(SampleRuns.take)
          assert_empty(observer.events)
        end
      end
    end
  end
end
