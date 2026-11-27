# frozen_string_literal: true

require_relative("../config_error")

module Stryker
  class CLI
    class Choice
      def self.listed(names, conjunction)
        quoted = names.map(&:inspect)
        count = quoted.size
        return quoted.join(" #{conjunction} ") if count < 3

        "#{quoted.take(count - 1).join(', ')}, #{conjunction} #{quoted.last}"
      end

      def initialize(option, what, known)
        @option = option
        @what = what
        @known = known
      end

      def check(names)
        unknown = names - @known
        return if unknown.empty?

        raise(
          ConfigError,
          "Stryker (for Ruby) has no #{@what} named #{Choice.listed(unknown, 'or')}. " \
            "The #{@option} option takes #{Choice.listed(@known, 'and')}."
        )
      end
    end
  end
end
