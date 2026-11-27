# frozen_string_literal: true

module Stryker
  class Pipeline
    class HeldBack
      attr_reader :runs

      def initialize(runs)
        @by_mutant = runs.to_h { |run| [run.mutant, run] }
        @runs = []
      end

      def hold?(result)
        timed_out = result.status == "Timeout"
        @runs << @by_mutant[result.mutant] if timed_out
        timed_out
      end

      # @dynamic runs
    end
  end
end
