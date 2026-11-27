# frozen_string_literal: true

require_relative "column_group"
require_relative "score_style"

module Stryker
  module Reporters
    class ScoreColumns
      COUNTS = { killed: "# killed", timeout: "# timeout", survived: "# survived", no_coverage: "# no cov" }.freeze
      private_constant(:COUNTS)

      def initialize(rows, high:, low:, ink:)
        @rows = rows
        @style = ScoreStyle.new(high:, low:)
        @ink = ink
      end

      def groups
        [file, scores, *counts, errors]
      end

      private def group(name, *columns)
        ColumnGroup.new(name, @ink, *columns)
      end

      private def file
        group("", LeftColumn.new("File", @rows) { |row| "#{' ' * row.depth}#{row.name}" })
      end

      private def scores
        group("% Mutation score", score("total", :mutation_score), score("covered", :covered_score))
      end

      private def score(header, kind)
        TableColumn.new(header, @rows, color: -> (row) { score_color(row, kind) }) { |row| row.score_text(kind) }
      end

      private def score_color(row, kind)
        @style.color(row.score(kind))
      end

      private def counts
        COUNTS.map { |member, header| count(member, header) }
      end

      private def count(member, header)
        group("", TableColumn.new(header, @rows) { |row| String(row.count(member)) })
      end

      private def errors
        group("", TableColumn.new("# errors", @rows) { |row| String(row.errors) })
      end
    end
  end
end
