# frozen_string_literal: true

require_relative "held_back"

module Stryker
  class Pipeline
    class StaticRuns
      def initialize(isolation)
        @isolation = isolation
      end

      def run_all(runs, &)
        held = HeldBack.new(runs)
        @isolation.run_all(runs) { |result| yield(result) unless held.hold?(result) }
        # Alone, a run has the machine to itself, as the dry run that its
        # time limit comes from had.
        held.runs.each { |run| @isolation.run_all([run], &) }
      end
    end
  end
end
