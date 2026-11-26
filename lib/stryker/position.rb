# frozen_string_literal: true

module Stryker
  class Position < Data.define(:line, :column)
    # @dynamic line, column
  end
end
