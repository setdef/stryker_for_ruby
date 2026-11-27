# frozen_string_literal: true

require_relative "../events"
require_relative "mutation_report"

module Stryker
  module Reporters
    class WholeRun
      def initialize(config:, root:)
        @config = config
        @root = root
        @tests = Array(nil)
      end

      def call(event)
        case event
        when Events::DryRunCompleted then @tests = event.result.results.map(&:test)
        when Events::RunCompleted then finish(event.results)
        end
      end

      private def finish(results)
        publish(MutationReport.new(config: @config, root: @root, tests: @tests, results:))
      end

      private def publish(_report)
        raise(NotImplementedError, "#{self.class} must define publish")
      end
    end
  end
end
