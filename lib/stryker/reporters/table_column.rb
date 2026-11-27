# frozen_string_literal: true

module Stryker
  module Reporters
    class TableColumn
      def initialize(header, rows, color: nil, &content)
        @header = header
        @color = color
        @content = content
        @net = [header.length, *rows.map { |row| yield(row).length }].max
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
        "#{' ' * (@net - text.length)} #{text} "
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
