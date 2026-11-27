# frozen_string_literal: true

require_relative "code_units"

module Stryker
  module Reporters
    class TableColumn
      def initialize(header, rows, color: nil, &content)
        @header = header
        @color = color
        @content = content
        @net = [header.length, *rows.map { |row| CodeUnits.width(yield(row)) }].max
      end

      def gap
        2
      end

      def widen(extra)
        @net += extra
      end

      def width
        @net + gap
      end

      def line
        "-" * width
      end

      def heading
        pad(@header)
      end

      def pad(text)
        "#{' ' * (@net - CodeUnits.width(text))} #{text} "
      end

      def cell(row)
        pad(@content.call(row))
      end

      def color(row)
        @color&.call(row)
      end

      def label(name)
        self.class.new(name, Array(nil)) { "" }
      end
    end
  end
end
