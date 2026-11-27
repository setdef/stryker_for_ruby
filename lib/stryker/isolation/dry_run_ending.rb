# frozen_string_literal: true

require_relative "timer"

module Stryker
  module Isolation
    class DryRunEnding < Data.define(:messages, :ending)
      UNSTARTED = "The dry run's process started no test within %<seconds>d seconds."
      private_constant(:UNSTARTED)

      def to_s
        # The end of standard error last, where a crash's report usually is.
        [messages.error || ended, ending.errors.chomp].reject(&:empty?).join("\n")
      end

      private def ended
        return format(UNSTARTED, seconds: Timer::START_SECONDS) if ending.timed_out

        test = messages.unfinished
        "The dry run's process #{ending.description}#{", while #{test.id} ran" if test}."
      end

      # @dynamic messages, ending
    end
  end
end
