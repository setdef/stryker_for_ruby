# frozen_string_literal: true

require_relative "error"
require_relative "flights"
require_relative "parent_launch"
require_relative "stop_on_raise"
require_relative "verdict"

module Stryker
  module Isolation
    class ForkPerRun
      STATIC = "Mutant %<id>p is static, and a fork has its parent's code already loaded, " \
        "so its run needs a fresh process."
      UNSTARTED = "The fork parent isn't running: call start first."
      private_constant(:STATIC, :UNSTARTED)

      def initialize(directory, root = Dir.pwd, launch = ParentLaunch.new(directory, root))
        @launch = launch
        @flights = nil
      end

      def start(config)
        parent = @launch.call(config.test_runner)
        parent.await_ready
        @flights = Flights.new(parent, config.concurrency)
        nil
      end

      def run_all(runs, &)
        static = runs.find(&:static)
        raise(ArgumentError, format(STATIC, id: static.mutant.id)) if static

        flights = @flights or raise(Error, UNSTARTED)
        StopOnRaise.around(self) { flights.run(runs, Verdict, &) }
      end

      def stop
        flights = @flights or return
        @flights = nil
        flights.stop
      end
    end
  end
end
