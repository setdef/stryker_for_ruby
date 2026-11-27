# frozen_string_literal: true

require_relative "span"

module Stryker
  module Reporters
    class MutationReport
      class TestEntry
        def initialize(test)
          @test = test
        end

        def to_h
          { id: @test.id, name: @test.name, location: span }.compact
        end

        private def span
          location = @test.location
          Span.new(location).to_h if location
        end
      end
    end
  end
end
