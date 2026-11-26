# frozen_string_literal: true

require_relative "../observer"
require_relative "../sample_runs"

module Stryker
  module Testing
    module TestRunnerContract
      module Sample
        def setup
          super
          SampleRuns.take
        end

        private def ids(*roles)
          sample_test_ids.slice(*roles).values
        end

        private def loaded_runner
          runner = runner_under_test
          runner.load_tests
          runner
        end

        private def run_roles(*roles, bail:)
          loaded_runner.run(ids(*roles), bail:, observer: Observer.new)
        end
      end
    end
  end
end
