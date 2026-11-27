# frozen_string_literal: true

require_relative "score_columns"

module Stryker
  module Reporters
    class ScoreTable
      def initialize(rows, high:, low:, ink:)
        @rows = rows
        @groups = ScoreColumns.new(rows, high:, low:, ink:).groups
      end

      def to_s
        rule = draw(&:lines)
        [draw(&:line), draw(&:header), draw(&:headings), rule, *body, rule].join("\n")
      end

      private def draw(&)
        "#{@groups.map(&).join('|')}|"
      end

      private def body
        @rows.map { |row| line_of(row) }
      end

      private def line_of(row)
        draw { |group| group.cells(row) }
      end
    end
  end
end
