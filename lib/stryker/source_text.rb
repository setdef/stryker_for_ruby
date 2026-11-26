# frozen_string_literal: true

require "prism"
require_relative "location"
require_relative "position"

module Stryker
  class SourceText
    def initialize(text)
      @text = text
      @prism_source = Prism.parse(text).source
    end

    def location(start_offset, end_offset)
      check(start_offset, end_offset)
      Location.new(position(start_offset), position(end_offset))
    end

    private def check(start_offset, end_offset)
      bad = [start_offset, end_offset].find { |offset| !boundary?(offset) }
      refuse("byte offset #{bad} is not on a character boundary") if bad
      refuse("start offset #{start_offset} is after end offset #{end_offset}") if start_offset > end_offset
    end

    private def boundary?(offset)
      # String#byteindex raises IndexError for an offset that is not on a
      # character boundary, and returns nil for one past the end of the text,
      # which is the check Ruby offers for both. A negative offset counts from
      # the end of the text there, so it needs a check of its own.
      !offset.negative? && @text.byteindex("", offset)
    rescue IndexError
      false
    end

    private def refuse(message)
      raise(ArgumentError, "#{message}, in a text of #{@text.bytesize} bytes")
    end

    private def position(offset)
      # The report places a replacement by JavaScript string index, which
      # counts UTF-16 code units. Prism counts columns from 0.
      Position.new(@prism_source.line(offset), @prism_source.code_units_column(offset, Encoding::UTF_16LE) + 1)
    end
  end
end
