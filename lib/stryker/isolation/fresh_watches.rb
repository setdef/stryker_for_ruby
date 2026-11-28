# frozen_string_literal: true

require_relative "cleanup"

module Stryker
  module Isolation
    class FreshWatches
      def initialize(io = IO)
        @io = io
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
          yield(waiting.shift) while size < window && waiting.any?
          finish
        end
      end

      def finish
        ready = wait
        @watches.each { |watch| watch.take(ready) }
        @watches.select(&:done?).each { |watch| land(watch) }
      end

      def stop
        Cleanup.run(*@watches.map { |watch| -> { watch.stop } })
      ensure
        @watches.clear
      end

      private def land(watch)
        # A run leaves the set once it has finished, so that a signal before
        # then finds it there, and stop ends it.
        watch.finish
        @watches.delete(watch)
      end

      private def wait
        # One wait for every run: until a process writes to its pipe or ends,
        # or the soonest run needs a look.
        seconds = @watches.map(&:wake_in).min or return []
        @io.select(@watches.filter_map(&:output), nil, nil, seconds)&.first || []
      end
    end
  end
end
