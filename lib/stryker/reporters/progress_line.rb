# frozen_string_literal: true

require_relative "ink"

module Stryker
  module Reporters
    class ProgressLine
      BAR_WIDTH = 50
      NO_INK = Ink.new(enabled: false)
      private_constant(:BAR_WIDTH, :NO_INK)

      def initialize(tally, elapsed:, ink:)
        @tally = tally
        @elapsed = elapsed
        @ink = ink
      end

      def bar(columns)
        room = columns - ProgressLine.new(@tally, elapsed: @elapsed, ink: NO_INK).frame("").length
        frame(filled(room.clamp(0, BAR_WIDTH)))
      end

      def frame(bar)
        "Mutation testing  [#{bar}] #{@tally.percent}% (#{@tally.times(@elapsed)}) " \
          "#{@tally.tested}/#{@tally.mutants} Mutants tested (#{counts})"
      end

      def plain
        "Mutation testing #{@tally.percent}% (#{@tally.times(@elapsed)}) " \
          "#{@tally.tested}/#{@tally.mutants} tested (#{counts})"
      end

      private def filled(width)
        done = (width * @tally.fraction).round
        "#{@ink.paint(:green, '=' * done)}#{' ' * (width - done)}"
      end

      private def counts
        [flag(:red, @tally.survived, "survived"), flag(:yellow, @tally.timed_out, "timed out")].join(", ")
      end

      private def flag(color, count, label)
        text = "#{count} #{label}"
        count.positive? ? @ink.paint(color, text) : text
      end
    end
  end
end
