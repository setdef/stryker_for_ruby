# frozen_string_literal: true

require_relative "deferred"
require_relative "dry_run"
require_relative "dry_run_verdict"
require_relative "error"
require_relative "fresh_folder"
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
        fly(runs) { |run, folder| FreshRun.judged(run, folder, &) }
      end

      def dry_run(config)
        dry_run = DryRun.within(config.dry_run_timeout_minutes)
        DryRunVerdict.awaited(dry_run) { |landing| land(dry_run, landing) }
      end

      def stop
        @running.stop
      end

      private def land(dry_run, landing)
        fly([dry_run]) { |run, folder| FreshRun.new(run, folder, &landing) }
      end

      private def fly(runs, &fresh)
        config = @config or raise(Error, UNSTARTED)
        recipe = config.test_runner_recipe
        StopOnRaise.around(self) do
          @running.run(runs, config.concurrency) { |run| held(run, fresh).launch(@launch, recipe) }
        end
      end

      private def held(run, fresh)
        # The set holds the run before the mask ends, so a signal that arrives
        # while the run's folder is made raises once the set holds the run,
        # and stop deletes the folder.
        Deferred.signals { fresh.call(run, FreshFolder.made).tap { |made| @running.add(made) } }
      end
    end
  end
end
