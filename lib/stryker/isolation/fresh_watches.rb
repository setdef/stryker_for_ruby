# frozen_string_literal: true

require_relative "fresh_watch"

module Stryker
  module Isolation
    class FreshWatches
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

      def finish
        ended = @watches.select(&:ended?)
        # With none ended, the run whose time ends first is waited for, until
        # it ends or its time does.
        ended = @watches.min_by(1, &:left) if ended.empty?
        ended.each do |watch|
          @watches.delete(watch)
          yield(watch.finish)
        end
      end

      def stop
        @watches.each(&:stop).clear
        nil
      end
    end
  end
end
