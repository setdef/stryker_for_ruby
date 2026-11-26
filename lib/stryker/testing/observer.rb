# frozen_string_literal: true

require_relative "sample_runs"

module Stryker
  module Testing
    class Observer
      attr_reader :events

      def initialize
        @events = []
      end

      def test_started(test)
        @events << [:started, test.id, SampleRuns.count]
      end

      def test_finished(result)
        @events << [:finished, result.test.id, SampleRuns.count]
      end

      # @dynamic events
    end
  end
end
