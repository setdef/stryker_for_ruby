# frozen_string_literal: true

require_relative "child"
require_relative "ending"
require_relative "timer"

module Stryker
  module Isolation
    class FreshWatch
      def initialize(fresh, child, timer)
        @fresh = fresh
        @child = child
        @timer = timer
      end

      def check
        # A fresh process writes its messages to a file, so the start of its
        # first test, which starts the run's time limit, shows only there.
        timer = @timer
        timer.tests_started if !timer.testing? && @fresh.started?
        nil
      end

      def testing?
        @timer.testing?
      end

      def done?
        @child.ended? || left.zero?
      end

      def wait(seconds)
        @child.wait(seconds)
      end

      def left
        @timer.left
      end

      def finish
        timed_out = @child.end_within(@timer.left)
        status = @child.status
        # What its tests started dies with it.
        @child.kill_rest
        @fresh.result(Ending.of(status, timed_out:, duration_ms: @timer.elapsed_ms))
      end

      def stop
        @child.stop
        @fresh.remove
      end
    end
  end
end
