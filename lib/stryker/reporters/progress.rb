# frozen_string_literal: true

require_relative "../events"
require_relative "ink"
require_relative "progress_animation"
require_relative "progress_log"
require_relative "progress_tally"
require_relative "progress_weights"
require_relative "stopwatch"

module Stryker
  module Reporters
    class Progress
      MONOTONIC = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      public_constant(:MONOTONIC)

      def self.animated(io:, columns:, color:)
        new(display: ProgressAnimation.new(io, columns, Ink.new(enabled: color)), clock: MONOTONIC)
      end

      def self.logged(io:, color:)
        new(display: ProgressLog.new(io, Ink.new(enabled: color)), clock: MONOTONIC)
      end

      def initialize(display:, clock:)
        @display = display
        @weights = ProgressWeights.none
        @tally = ProgressTally.new({})
        @watch = Stopwatch.new(clock)
      end

      def call(event)
        case event
        when Events::DryRunCompleted then timed(event)
        when Events::PlanReady then planned(event)
        when Events::MutantTested then tested(event)
        when Events::RunCompleted, Events::RunAborted then @display.finish
        end
      end

      private def timed(event)
        @weights = ProgressWeights.of(event.result)
      end

      private def tested(event)
        show if @tally.record(event.result)
      end

      private def planned(event)
        runs = event.runs
        @watch.restart
        @tally = ProgressTally.new(runs.to_h { |run| [run.mutant.id, @weights.of(run)] })
        show unless runs.empty?
      end

      private def show
        @display.update(@tally, @watch.elapsed)
      end
    end
  end
end
