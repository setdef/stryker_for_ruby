# frozen_string_literal: true

require_relative "file_tree"
require_relative "score_table"
require_relative "test_tree"
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
        "#{['', *tests, '', *undetected(rows), average, table].join("\n")}\n"
      end

      private def tests
        TestTree.new(@report.tests, @report.mutants, @ink).lines
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
