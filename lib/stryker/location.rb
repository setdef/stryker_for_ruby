# frozen_string_literal: true

require_relative "json_value"
require_relative "position"

module Stryker
  class Location < Data.define(:start, :end)
    include JsonValue

    def self.readers
      position = Position.method(:from_h).to_proc
      { start: position, end: position }
    end

    # @dynamic start, end
  end
end
