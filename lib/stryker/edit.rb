# frozen_string_literal: true

module Stryker
  class Edit < Data.define(:start_offset, :end_offset, :replacement, :description)
    def self.over(span, replacement, description = nil)
      new(start_offset: span.start_offset, end_offset: span.end_offset, replacement:, description:)
    end

    def initialize(description: nil, **)
      super
    end

    # @dynamic start_offset, end_offset, replacement, description, to_h
  end
end
