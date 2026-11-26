# frozen_string_literal: true

module Stryker
  module Testing
    module SampleRuns
      RUNS = Thread::Queue.new
      private_constant(:RUNS)

      def self.ran(role)
        RUNS << role
        nil
      end

      def self.take
        Array.new(RUNS.size) { RUNS.pop }
      end

      def self.count
        RUNS.size
      end
    end
  end
end
