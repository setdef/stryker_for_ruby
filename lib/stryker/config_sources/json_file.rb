# frozen_string_literal: true

require "English"
require "json"
require_relative("text_file")

module Stryker
  module ConfigSources
    class JsonFile < TextFile
      BYTE_ORDER_MARK = "\uFEFF"
      BYTE_ORDER_MARK_PROBLEM = "isn't valid JSON: it starts with a byte-order mark, which JSON doesn't allow. " \
        "Save the file as UTF-8 without one."
      private_constant(:BYTE_ORDER_MARK, :BYTE_ORDER_MARK_PROBLEM)

      private def parse(text)
        raise(invalid(BYTE_ORDER_MARK_PROBLEM)) if text.start_with?(BYTE_ORDER_MARK)

        JSON.parse(text)
      rescue JSON::ParserError
        raise(invalid("isn't valid JSON: #{$ERROR_INFO.to_s.lines.first.to_s.strip}"))
      end
    end
  end
end
