# frozen_string_literal: true

module Stryker
  module Reporters
    class TestOutcomes
      class Outcome < Data.define(:killed, :covered)
        def style
          return [:green_bright, "✓", "killed #{killed}"] if killed.positive?
          return [:blue_bright, "~", "covered #{covered}"] if covered.positive?

          [:red_bright, "✘", "covered 0"]
        end

        # @dynamic killed, covered
      end

      def initialize(mutants)
        @mutants = mutants
      end

      def of(id)
        Outcome.new(killed: named(:killed_by, id), covered: named(:covered_by, id))
      end

      private def named(member, id)
        @mutants.sum { |mutant| mutant.public_send(member).count(id) }
      end
    end
  end
end
