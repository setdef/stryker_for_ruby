# frozen_string_literal: true

module Stryker
  module Reporters
    module DurationText
      SECONDS_IN_HOUR = 3600
      SECONDS_IN_MINUTE = 60
      private_constant(:SECONDS_IN_HOUR, :SECONDS_IN_MINUTE)

      def self.of(seconds)
        hours, rest = seconds.divmod(SECONDS_IN_HOUR)
        minutes = rest / SECONDS_IN_MINUTE
        return "~#{hours}h #{minutes}m" if hours.positive?

        minutes.positive? ? "~#{minutes}m" : "<1m"
      end
    end
  end
end
