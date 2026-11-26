# frozen_string_literal: true

module Stryker
  class Instrumenter
    class Error < StandardError
      def self.unparsable(errors, subject)
        lines = errors.map { |error| "#{error.message}, on line #{error.location.start_line}" }
        new("The #{subject} doesn't parse: #{lines.join('; ')}.")
      end
    end
  end
end
