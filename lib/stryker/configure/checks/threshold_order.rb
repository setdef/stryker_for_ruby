# frozen_string_literal: true

require_relative("../settings")

module Stryker
  class Configure
    module Checks
      class ThresholdOrder
        HIGH = "thresholds.high"
        LOW = "thresholds.low"
        private_constant(:HIGH, :LOW)

        def initialize(merged)
          @high = Settings.effective(merged, HIGH)
          @low = Settings.effective(merged, LOW)
        end

        def to_a
          inverted? ? [message] : []
        end

        private def inverted?
          high = @high.value
          low = @low.value
          high.is_a?(Numeric) && low.is_a?(Numeric) && high < low
        end

        private def message
          "#{@high.mention} is #{@high.value}, which is below #{@low.mention} (#{@low.value}). " \
            "\"#{HIGH}\" can't be below \"#{LOW}\"."
        end
      end
    end
  end
end
