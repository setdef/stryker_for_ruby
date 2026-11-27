# frozen_string_literal: true

module Stryker
  class CLI
    class BugReport
      ISSUES = "https://github.com/setdef/stryker_for_ruby/issues/new"
      public_constant(:ISSUES)

      def initialize(error)
        @error = error
      end

      def to_s
        <<~TEXT.chomp
          Stryker (for Ruby) stopped because of a bug: #{@error.class}: #{@error.message}
          #{Array(@error.backtrace).join("\n")}
          Report it at #{ISSUES}
        TEXT
      end
    end
  end
end
