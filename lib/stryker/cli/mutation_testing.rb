# frozen_string_literal: true

require_relative("../unsupported_error")
require_relative("choice")

module Stryker
  class CLI
    class MutationTesting
      FORKS = Process.respond_to?(:fork)
      NO_FORK = "A run on Windows isn't built yet: Stryker (for Ruby) runs each runtime mutant in a process " \
        "forked from one that loaded the project, and Windows has no fork."
      private_constant(:FORKS, :NO_FORK)

      def initialize(root, forks: FORKS, pipeline: nil)
        @root = root
        @forks = forks
        @pipeline = pipeline
      end

      def call(config, streams, color)
        prepare(config)
        reporters = Reporting.new(config, @root).reporters(streams, color)
        stderr = streams.stderr
        pipeline(reporters, stderr).call(Templates.new(config, @root).config(stderr))
      end

      private def pipeline(reporters, warnings)
        (@pipeline || Pipeline).new(@root, -> (cache) { isolations(cache) }, reporters, warnings:)
      end

      private def prepare(config)
        raise(UnsupportedError, NO_FORK) unless @forks

        # Prism and refract cost most of the command's start-up, and only a run
        # uses them, so `stryker --version` and `stryker help` load none of it.
        require_relative("stages")
        Choice.new("testRunner", "test runner", TestRunners::BY_NAME.keys).check([config.test_runner])
      end

      private def isolations(cache)
        [Isolation::ForkPerRun.new(cache, @root), Isolation::FreshProcesses.new(cache, @root)]
      end
    end
  end
end
