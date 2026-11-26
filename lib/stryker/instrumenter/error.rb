# frozen_string_literal: true

require "prism"

module Stryker
  class Instrumenter
    class Error < StandardError
      def self.unknown_syntax(ruby_version)
        new("Prism #{Prism::VERSION} doesn't know the syntax of Ruby #{ruby_version}. Install a newer prism gem.")
      end

      def self.unparsable(errors, subject)
        lines = errors.map { |error| "#{error.message}, on line #{error.location.start_line}" }
        new("The #{subject} doesn't parse: #{lines.join('; ')}.")
      end
    end
  end
end
