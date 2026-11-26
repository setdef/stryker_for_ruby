# frozen_string_literal: true

require "prism"
require_relative "location"
require_relative "position"

module Stryker
  class SourceText
    def initialize(text)
      @prism_source = Prism.parse(text).source
    end

    def location(start_offset, end_offset)
      Location.new(position(start_offset), position(end_offset))
    end

    private def position(offset)
      # The report places a replacement by JavaScript string index, which
      # counts UTF-16 code units. Prism counts columns from 0.
      Position.new(@prism_source.line(offset), @prism_source.code_units_column(offset, Encoding::UTF_16LE) + 1)
    end
  end
end
