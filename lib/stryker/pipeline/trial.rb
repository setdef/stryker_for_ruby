# frozen_string_literal: true

require_relative "../config_error"
require_relative "../events/dry_run_completed"
require_relative "../plan"
require_relative "outcome"
require_relative "results"

module Stryker
  class Pipeline
    class Trial
      NO_TEST = "The dry run found no test, so no mutant can be tested. A minitest.testFiles pattern that " \
        "matches no test file is the likeliest cause: check the patterns. To accept that, and end the run with " \
        "status 0, no mutant tested, and no report, set allowEmpty to true."
      private_constant(:NO_TEST)

      def initialize(config, broadcast)
        @config = config
        @broadcast = broadcast
        @results = Results.new(broadcast)
      end

      def call(isolations, instrumented)
        found = dry_run(isolations)
        found.no_test? ? Outcome.untested : Outcome.tested(planned(isolations, instrumented, found))
      end

      private def dry_run(isolations)
        found = isolations.dry_run(@config)
        raise(ConfigError, NO_TEST) if found.no_test? && !@config.allow_empty

        @broadcast.call(Events::DryRunCompleted.new(result: found))
        found
      end

      private def planned(isolations, instrumented, found)
        ready = instrumented.planned(Plan.new(found, @config))
        @broadcast.call(ready)
        tested(isolations, ready)
      end

      private def tested(isolations, ready)
        @results.add_all(ready.unrun)
        isolations.run_all(ready.runs) { |result| @results.add(result) }
        @results.to_a
      end
    end
  end
end
