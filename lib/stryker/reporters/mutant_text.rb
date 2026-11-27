# frozen_string_literal: true

module Stryker
  module Reporters
    class MutantText
      def initialize(mutant, tests_ran, ink)
        @mutant = mutant
        @tests_ran = tests_ran
        @ink = ink
      end

      def lines
        excerpt = @mutant.excerpt
        [
          "[#{@mutant.status}] #{@mutant.mutator_name}",
          where,
          *quoted("-", :red, excerpt.original),
          *quoted("+", :green, excerpt.mutated),
          *@tests_ran.lines,
          "",
        ]
      end

      private def where
        start = @mutant.location.start
        [
          @ink.paint(:cyan, @mutant.path),
          @ink.paint(:yellow, start.line.to_s),
          @ink.paint(:yellow, start.column.to_s),
        ].join(":")
      end

      private def quoted(sign, color, text)
        text.split("\n").filter_map { |line| @ink.paint(color, "#{sign}   #{line}") unless line.empty? }
      end
    end
  end
end
