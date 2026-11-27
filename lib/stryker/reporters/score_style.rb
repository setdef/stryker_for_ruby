# frozen_string_literal: true

module Stryker
  module Reporters
    class ScoreStyle
      def initialize(high:, low:)
        @high = high
        @low = low
      end

      def color(score)
        return :grey unless score
        return :green if score >= @high

        (score >= @low) ? :yellow : :red
      end
    end
  end
end
