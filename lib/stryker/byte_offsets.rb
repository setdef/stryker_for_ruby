# frozen_string_literal: true

module Stryker
  module ByteOffsets
    def self.check(text, start_offset, end_offset)
      bad = [start_offset, end_offset].find { |offset| !boundary?(text, offset) }
      refuse(text, "byte offset #{bad} is not on a character boundary") if bad
      refuse(text, "start offset #{start_offset} is after end offset #{end_offset}") if start_offset > end_offset
    end

    def self.boundary?(text, offset)
      # String#byteindex raises IndexError for an offset that is not on a
      # character boundary, and returns nil for one past the end of the text,
      # which is the check Ruby offers for both. A negative offset counts from
      # the end of the text there, so it needs a check of its own.
      !offset.negative? && text.byteindex("", offset)
    rescue IndexError
      false
    end

    def self.refuse(text, message)
      raise(ArgumentError, "#{message}, in a text of #{text.bytesize} bytes")
    end
    private_class_method(:refuse)
  end
end
