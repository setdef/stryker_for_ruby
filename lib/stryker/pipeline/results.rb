# frozen_string_literal: true

require_relative "../events/mutant_tested"

module Stryker
  class Pipeline
    class Results
      def initialize(broadcast)
        @broadcast = broadcast
        @collected = []
      end

      def add(result)
        @collected << result
        @broadcast.call(Events::MutantTested.new(result:))
      end

      def add_all(results)
        results.each { |result| add(result) }
        nil
      end

      def to_a
        @collected.sort_by { |result| result.mutant.id }
      end
    end
  end
end
