# frozen_string_literal: true

require_relative "../events/dry_run_completed"
require_relative "../plan"
require_relative "results"

module Stryker
  class Pipeline
    class Trial
      def initialize(config, broadcast)
        @config = config
        @broadcast = broadcast
        @results = Results.new(broadcast)
      end

      def call(isolations, instrumented)
        ready = instrumented.planned(Plan.new(dry_run(isolations), @config))
        @broadcast.call(ready)
        tested(isolations, ready)
      end

      private def dry_run(isolations)
        found = isolations.dry_run(@config)
        @broadcast.call(Events::DryRunCompleted.new(result: found))
        found
      end

      private def tested(isolations, ready)
        @results.add_all(ready.unrun)
        isolations.run_all(ready.runs) { |result| @results.add(result) }
        @results.to_a
      end
    end
  end
end
