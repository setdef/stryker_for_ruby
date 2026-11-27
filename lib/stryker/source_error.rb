# frozen_string_literal: true

module Stryker
  class SourceError < StandardError
    def self.unparsable(path, error)
      new(
        "#{path} doesn't parse as Ruby #{RUBY_VERSION}: #{error.message}, on line #{error.location.start_line}. " \
          "Fix the file, or leave it out of the mutate option."
      )
    end
  end
end
