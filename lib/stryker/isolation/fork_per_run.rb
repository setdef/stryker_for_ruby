# frozen_string_literal: true

require_relative "deferred"
require_relative "dry_run"
require_relative "dry_run_verdict"
require_relative "error"
require_relative "flight"
require_relative "flights"
require_relative "forkable_runs"
require_relative "parent_launch"
require_relative "stop_on_raise"

module Stryker
  module Isolation
    class ForkPerRun
      UNSTARTED = "The fork parent isn't running: call start first."
      private_constant(:UNSTARTED)

      def initialize(directory, root = Dir.pwd, launch = ParentLaunch.new(directory, root))
        @launch = launch
        @flights = nil
      end

      def start(config)
        StopOnRaise.around(self) do
          # A signal waits until the adapter holds the parent it launched, so
          # that stop reaches the parent however the start ends.
          parent = Deferred.signals { hold(@launch.call(config.test_runner_recipe), config) }
          parent.await_ready
        end
      end

      def run_all(runs, &)
        fly(ForkableRuns.new(runs).checked.map { |run| Flight.judged(run, &) })
      end

      def dry_run(config)
        dry_run = DryRun.within(config.dry_run_timeout_minutes)
        DryRunVerdict.awaited(dry_run) { |landing| fly([Flight.new(dry_run, &landing)]) }
      end

      def stop
        flights = @flights or return
        @flights = nil
        flights.stop
      end

      private def hold(parent, config)
        @flights = Flights.new(parent, config.concurrency)
        parent
      end

      private def fly(list)
        flights = @flights or raise(Error, UNSTARTED)
        StopOnRaise.around(self) { flights.run(list) }
      end
    end
  end
end
