# frozen_string_literal: true

module Stryker
  module Reporters
    class TestsRan
      MOST = 3
      private_constant(:MOST)

      def initialize(mutant, test_names)
        @mutant = mutant
        @names = mutant.covered_by.uniq.filter_map { |id| test_names[id] }
      end

      def lines
        return [] unless @mutant.survived?
        return ["Ran all tests for this mutant."] if @mutant.static?

        @names.empty? ? [] : ["Tests ran:", *@names.first(MOST).map { |name| "    #{name}" }, *more, ""]
      end

      private def more
        remaining.positive? ? ["  and #{remaining} more test#{'s' if remaining > 1}!"] : []
      end

      private def remaining
        @names.size - MOST
      end
    end
  end
end
