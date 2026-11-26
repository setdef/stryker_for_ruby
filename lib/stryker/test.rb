# frozen_string_literal: true

require_relative "json_value"
require_relative "location"

module Stryker
  class Test < Data.define(:id, :name, :file, :location)
    include JsonValue

    def self.readers
      { location: -> (value) { value && Location.from_h(value) } }
    end

    # @dynamic id, name, file, location
  end
end
