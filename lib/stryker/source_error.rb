# frozen_string_literal: true

require_relative "file_name"

module Stryker
  class SourceError < StandardError
    def self.unparsable(path, error)
      new(
        "#{FileName.shown(path)} doesn't parse as Ruby #{RUBY_VERSION}: #{error.message}, " \
          "on line #{error.location.start_line}. Fix the file, or leave it out of the mutate option."
      )
    end
  end
end
