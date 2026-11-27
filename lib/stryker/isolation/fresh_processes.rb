# frozen_string_literal: true

require_relative "error"
require_relative "fresh_launch"
require_relative "fresh_watches"
require_relative "stop_on_raise"

module Stryker
  module Isolation
    class FreshProcesses
      UNSTARTED = "The adapter has no options for its runs: call start first."
      private_constant(:UNSTARTED)

      def initialize(directory, root = Dir.pwd, launch = FreshLaunch.new(directory, root))
        @launch = launch
        @config = nil
        @running = FreshWatches.new
      end

      def start(config)
        @config = config
        nil
      end

      def run_all(runs, &)
        config = @config or raise(Error, UNSTARTED)
        waiting = runs.dup
        StopOnRaise.around(self) { step(waiting, config, &) until waiting.empty? && @running.empty? }
      end

      def stop
        @running.stop
      end

      private def step(waiting, config, &)
        runner = config.test_runner
        @running.add(@launch.call(waiting.shift, runner)) while @running.size < config.concurrency && waiting.any?
        @running.finish(&)
      end
    end
  end
end
