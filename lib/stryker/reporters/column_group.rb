# frozen_string_literal: true

require_relative "left_column"

module Stryker
  module Reporters
    class ColumnGroup
      def initialize(name, ink, *columns)
        @ink = ink
        @columns = columns
        @lead = columns.first or raise(ArgumentError, "a group needs a column")
        @label = @lead.label(name)
        fit(name.length)
      end

      def header
        @label.heading
      end

      def line
        @label.line
      end

      def headings
        @columns.map(&:heading).join("|")
      end

      def lines
        @columns.map(&:line).join("|")
      end

      def cells(row)
        cells = @columns.map { |column| paint(column.color(row), column.cell(row)) }
        cells.join("|")
      end

      private def paint(color, text)
        color ? @ink.paint(color, text) : text
      end

      private def fit(title)
        # SPDX-SnippetBegin
        # SPDX-License-Identifier: Apache-2.0
        # SPDX-SnippetCopyrightText: Stryker Mutator contributors
        # SPDX-SnippetComment: Ported from the GroupColumn constructor in
        # packages/core/src/reporters/clear-text-score-table.ts of StrykerJS. The port keeps the
        # group's label in a column of its own, where the original makes the group a column.
        inner = @columns.sum(&:width) - @lead.gap
        net = [title, inner].max
        @label.widen(net - title)
        @lead.widen(net - inner - 1) if net > inner + 1
        # SPDX-SnippetEnd
      end
    end
  end
end
