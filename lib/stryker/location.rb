# frozen_string_literal: true

require_relative "position"

module Stryker
  # steep:ignore:start
  class Location < Data.define(:start, :end)
    # steep:ignore:end
  end
end
