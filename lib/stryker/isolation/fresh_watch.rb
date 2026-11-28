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
        @ended = false
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
        @fresh.land(ended)
      end

      def stop
        @child.stop unless @ended
        @ended = true
      ensure
        @fresh.remove
      end

      private def ended
        # @type var ending: Ending?
        ending = nil
        ending = reaped(@child.end_within(@timer.left))
      ensure
        # Whatever raised, or whichever signal came, before the run landed:
        # nobody else holds the process or its folder.
        stop unless ending
      end

      private def reaped(timed_out)
        # A stop from here on must not kill the group again, whose ID may
        # belong to another process by now.
        @ended = true
        Ending.of(reaped_status, timed_out:, duration_ms: @timer.elapsed_ms)
      end

      private def reaped_status
        @child.status
      ensure
        # What its tests started dies with it, whether or not the status
        # could be read.
        @child.kill_rest
      end
    end
  end
end
