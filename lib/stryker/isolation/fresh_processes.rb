# frozen_string_literal: true

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
        DryRunVerdict.awaited(dry_run) { |landing| land(FreshRun.new(dry_run, &landing)) }
      end

      def stop
        @running.stop
      end

      private def land(fresh)
        fly([fresh.run]) { fresh }
      end

      private def fly(runs, &fresh)
        config = @config or raise(Error, UNSTARTED)
        launching = launcher(config.test_runner, fresh)
        StopOnRaise.around(self) { @running.run(runs, config.concurrency, &launching) }
      end

      private def launcher(runner, fresh)
        -> (run) { @launch.call(fresh.call(run), runner) }
      end
    end
  end
end
