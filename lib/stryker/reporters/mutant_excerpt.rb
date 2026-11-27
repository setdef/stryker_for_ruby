# frozen_string_literal: true

require_relative "code_units"

module Stryker
  module Reporters
    class MutantExcerpt
      def initialize(source, location, replacement)
        first = location.start
        last = location.end
        @lines = Array(source.lines[(first.line - 1)..(last.line - 1)])
        @from = first.column - 1
        @to = last.column - 1
        @replacement = replacement
      end

      def original
        @lines.join
      end

      def mutated
        "#{CodeUnits.head(@lines.first.to_s, @from)}#{@replacement}#{CodeUnits.tail(@lines.last.to_s, @to)}"
      end
    end
  end
end
