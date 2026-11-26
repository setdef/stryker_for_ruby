# frozen_string_literal: true

require_relative "json_value"

module Stryker
  class Position < Data.define(:line, :column)
    include JsonValue

    # @dynamic line, column
  end
end
