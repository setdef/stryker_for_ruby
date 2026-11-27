# frozen_string_literal: true

module Stryker
  module Reporters
    module TwoDecimals
      def self.of(number)
        return "NaN" if number.nan?

        hundredths = ((Rational(number) * 100) + Rational(1, 2)).floor
        whole, part = hundredths.divmod(100)
        "#{whole}.#{part.to_s.rjust(2, '0')}"
      end
    end
  end
end
