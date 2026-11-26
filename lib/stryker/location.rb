# frozen_string_literal: true

require_relative "position"

module Stryker
  class Location < Data.define(:start, :end)
    # @dynamic start, end
  end
end
