# frozen_string_literal: true

require_relative "fresh_watch"

module Stryker
  module Isolation
    class FreshWatches
      POLL_SECONDS = 0.1
      public_constant(:POLL_SECONDS)

      def initialize
        @watches = []
      end

      def add(watch)
        @watches << watch
        nil
      end

      def size
        @watches.size
      end

      def empty?
        @watches.empty?
      end

      def run(runs, window)
        waiting = runs.dup
        until waiting.empty? && empty?
          add(yield(waiting.shift)) while size < window && waiting.any?
          finish
        end
      end

      def finish
        @watches.each(&:check)
        pause if @watches.none?(&:done?)
        @watches.select(&:done?).each do |watch|
          @watches.delete(watch)
          watch.finish
        end
      end

      def stop
        @watches.each(&:stop).clear
        nil
      end

      private def pause
        # The run whose time ends first is waited for, until it ends or its
        # time does. While a run has started no test, the wait is short, so
        # the start of its first test, which only its results file shows,
        # starts its limit soon after it happens.
        soonest = @watches.min_by(&:left) or return
        seconds = soonest.left
        seconds = [seconds, POLL_SECONDS].min unless @watches.all?(&:testing?)
        soonest.wait(seconds)
      end
    end
  end
end
