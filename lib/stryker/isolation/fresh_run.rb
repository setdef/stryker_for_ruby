# frozen_string_literal: true

require_relative "deferred"
require_relative "fresh_run/made"
require_relative "fresh_run/stage"
require_relative "verdict"

module Stryker
  module Isolation
    class FreshRun
      attr_reader :run

      def self.judged(run, folder)
        new(run, folder) { |messages, ending| yield(Verdict.new(run, messages, ending).result) }
      end

      def initialize(run, folder, &landing)
        @run = run
        @landing = landing
        @stage = Made.new(folder)
      end

      def launch(launch, recipe)
        hand_over { @stage.spawn(launch, @run, recipe) }
      end

      def output
        @stage.output
      end

      def take(ready)
        @stage.take(ready)
      end

      def wake_in
        @stage.wake_in
      end

      def done?
        @stage.done?
      end

      def finish
        # Reaped before it lands, so that a stop while it lands leaves alone
        # the process, whose ID may belong to another process by then.
        @stage = @stage.reap
        @stage.land(@landing)
      end

      def stop
        @stage.stop
        @stage = Stage.new
        nil
      end

      private def hand_over
        # The run holds what the step made before the mask ends, so a signal
        # that arrives during the step raises once the run holds it, and stop
        # ends it.
        Deferred.signals { @stage = yield }
        nil
      end

      # @dynamic run
    end
  end
end
