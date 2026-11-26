# frozen_string_literal: true

module Stryker
  class Edit < Data.define(:start_offset, :end_offset, :replacement)
    def self.over(span, replacement)
      new(start_offset: span.start_offset, end_offset: span.end_offset, replacement:)
    end

    # @dynamic start_offset, end_offset, replacement, to_h
  end
end
