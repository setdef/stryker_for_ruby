# frozen_string_literal: true

require_relative("../isolation/fork_per_run")
require_relative("../isolation/fresh_processes")
require_relative("../pipeline")
require_relative("../test_runners")
require_relative("../unsupported_error")
require_relative("choice")
require_relative("reporting")

module Stryker
  class CLI
    class MutationTesting
      FORKS = Process.respond_to?(:fork)
      NO_FORK = "A run on Windows isn't built yet: Stryker (for Ruby) runs each runtime mutant in a process " \
        "forked from one that loaded the project, and Windows has no fork."
      private_constant(:FORKS, :NO_FORK)

      def initialize(root, forks: FORKS, pipeline: Pipeline)
        @root = root
        @forks = forks
        @pipeline = pipeline
      end

      def call(config, streams, color)
        raise(UnsupportedError, NO_FORK) unless @forks

        Choice.new("testRunner", "test runner", TestRunners::BY_NAME.keys).check([config.test_runner])
        reporters = Reporting.new(config, @root).reporters(streams.stdout, color)
        @pipeline.new(@root, -> (cache) { isolations(cache) }, reporters).call(config)
      end

      private def isolations(cache)
        [Isolation::ForkPerRun.new(cache, @root), Isolation::FreshProcesses.new(cache, @root)]
      end
    end
  end
end
