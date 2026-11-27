# frozen_string_literal: true

require_relative "watch"

module Stryker
  module Isolation
    class Watches
      def initialize
        @watches = {}
      end

      def add(watch)
        @watches[watch.output] = watch
        nil
      end

      def wait(inputs, &)
        # One thread waits on every process's output, and on the inputs,
        # until the first deadline.
        ready = IO.select([*inputs, *@watches.keys], nil, nil, first_deadline)&.first || []
        [ready & inputs, ended(ready, &)]
      end

      def stop
        @watches.each_value(&:stop)
        @watches.clear
        nil
      end

      private def first_deadline
        @watches.each_value.map(&:left).min
      end

      private def ended(ready, &)
        done = @watches.select { |_, watch| watch.done?(ready, &) }
        @watches = @watches.except(*done.keys)
        done.each_value.map { |watch| watch.finish(&) }
      end
    end
  end
end
