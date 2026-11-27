# frozen_string_literal: true

require_relative "file_tree"
require_relative "score_table"
require_relative "two_decimals"
require_relative "undetected_mutants"

module Stryker
  module Reporters
    class Summary
      def initialize(report, ink:, high:, low:)
        @report = report
        @ink = ink
        @high = high
        @low = low
      end

      def to_s
        rows = FileTree.new(@report.file_entries).rows
        table = ScoreTable.new(rows, ink: @ink, high: @high, low: @low)
        "#{['', '', *undetected(rows), average, table].join("\n")}\n"
      end

      private def undetected(rows)
        UndetectedMutants.new(@report.test_names, @ink).lines(rows.filter_map(&:file))
      end

      private def average
        "Ran #{TwoDecimals.of(@report.tests_completed.fdiv(@report.mutant_count))} tests per mutant on average."
      end
    end
  end
end
