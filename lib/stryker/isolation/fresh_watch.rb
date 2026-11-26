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

      def ended?
        @child.ended?
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
