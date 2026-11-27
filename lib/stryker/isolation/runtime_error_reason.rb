# frozen_string_literal: true

require_relative "timer"

module Stryker
  module Isolation
    class RuntimeErrorReason
      UNSTARTED = "The run's process started no test within %<seconds>d seconds, so no test judged the mutant."
      private_constant(:UNSTARTED)

      def initialize(run, messages, ending)
        @run = run
        @messages = messages
        @ending = ending
      end

      def to_s
        # The end of standard error last, where a crash's report usually is.
        [@messages.error || ended, @ending.errors.chomp].reject(&:empty?).join("\n")
      end

      private def ended
        return format(UNSTARTED, seconds: Timer::START_SECONDS) if @ending.timed_out

        test = @messages.unfinished
        during = test ? ", while #{test.id} ran" : ""
        "The run's process #{@ending.description} after #{@messages.results.size} of its " \
          "#{@run.test_ids.size} tests finished#{during}."
      end
    end
  end
end
