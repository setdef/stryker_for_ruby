# frozen_string_literal: true

module Stryker
  module Reporters
    class MutationReport
      class Span
        def initialize(location)
          @location = location
        end

        def to_h
          { start: @location.start.to_h, end: @location.end.to_h }
        end
      end
    end
  end
end
