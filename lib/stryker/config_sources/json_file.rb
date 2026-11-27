# frozen_string_literal: true

require "English"
require "json"
require_relative("json_text")
require_relative("text_file")

module Stryker
  module ConfigSources
    class JsonFile < TextFile
      private def parse(text)
        problem = JsonText.new(text).problem
        raise(invalid("isn't valid JSON: #{problem}")) if problem

        JSON.parse(text)
      rescue JSON::ParserError
        raise(invalid("isn't valid JSON: #{$ERROR_INFO.to_s.lines.first.to_s.strip}"))
      end
    end
  end
end
