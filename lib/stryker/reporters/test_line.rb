# frozen_string_literal: true

module Stryker
  module Reporters
    class TestLine
      def initialize(test, outcomes, ink)
        @test = test
        @outcomes = outcomes
        @ink = ink
      end

      def to_s
        color, mark, state = @outcomes.of(@test.id).style
        "#{@ink.paint(color, mark)} #{@ink.paint(:grey, label)} (#{state})"
      end

      private def label
        line = @test.location&.start&.line
        [@test.name, *("[line #{line}]" if line)].join(" ")
      end
    end
  end
end
