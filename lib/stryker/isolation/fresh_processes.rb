# frozen_string_literal: true

require_relative "deferred"
require_relative "dry_run"
require_relative "dry_run_verdict"
require_relative "error"
require_relative "fresh_launch"
require_relative "fresh_run"
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
        fly(runs) { |run| FreshRun.judged(run, &) }
      end

      def dry_run(config)
        dry_run = DryRun.within(config.dry_run_timeout_minutes)
        DryRunVerdict.awaited(dry_run) { |landing| land(dry_run, landing) }
      end

      def stop
        @running.stop
      end

      private def land(dry_run, landing)
        # The run's folder is made where the set holds what it makes.
        fly([dry_run]) { |run| FreshRun.new(run, &landing) }
      end

      private def fly(runs, &fresh)
        config = @config or raise(Error, UNSTARTED)
        launching = launcher(config.test_runner_recipe, fresh)
        StopOnRaise.around(self) { @running.run(runs, config.concurrency, &launching) }
      end

      private def launcher(recipe, fresh)
        # What the launch makes and starts, a run's folder and its process,
        # is in the set before a signal arrives, so that stop ends it. The
        # step only makes and starts, so a signal waits briefly, never for a
        # run.
        -> (run) { Deferred.signals { @running.add(@launch.call(fresh.call(run), recipe)) } }
      end
    end
  end
end
