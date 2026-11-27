# frozen_string_literal: true

require_relative "progress_line"

module Stryker
  module Reporters
    class ProgressAnimation
      REDRAW = "\r"
      CLEAR_REST_OF_LINE = "\e[K"
      private_constant(:REDRAW, :CLEAR_REST_OF_LINE)

      def initialize(io, columns, ink)
        @io = io
        @columns = columns
        @ink = ink
        @drawn = false
      end

      def update(tally, elapsed)
        line = ProgressLine.new(tally, elapsed:, ink: @ink)
        @io.write("#{REDRAW}#{line.bar(@columns)}#{CLEAR_REST_OF_LINE}")
        @drawn = true
      end

      def finish
        @io.write("\n") if @drawn
      end
    end
  end
end
