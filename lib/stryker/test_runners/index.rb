# frozen_string_literal: true

module Stryker
  module TestRunners
    class Index
      def initialize
        @runnables = {}
      end

      def add(runnable)
        @runnables[runnable.test.id] = runnable
      end

      def key?(id)
        @runnables.key?(id)
      end

      def tests
        @runnables.each_value.map(&:test)
      end

      def chosen(ids)
        ids.map { |id| @runnables.fetch(id) { raise(ArgumentError, "No test has the ID #{id.inspect}.") } }
      end
    end
  end
end
