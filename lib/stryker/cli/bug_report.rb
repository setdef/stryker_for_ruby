# frozen_string_literal: true

require_relative("help")

module Stryker
  class CLI
    class BugReport
      def initialize(error)
        @error = error
      end

      def summary
        "Stryker (for Ruby) stopped because of a bug: #{@error.class}"
      end

      def to_s
        <<~TEXT.chomp
          #{summary}: #{@error.message}
          #{Array(@error.backtrace).join("\n")}
          Report it on the forum at #{Help::FORUM}
          Include the command you ran, what it printed, your Ruby version,
          your operating system, and the backtrace above.
        TEXT
      end
    end
  end
end
