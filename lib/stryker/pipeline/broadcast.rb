# frozen_string_literal: true

require_relative("raised")

module Stryker
  class Pipeline
    class Broadcast
      def initialize(reporters)
        @reporters = reporters
      end

      def call(event)
        errors = @reporters.filter_map { |reporter| Raised.by { reporter.call(event) } }
        raise(errors.first) if errors.any?

        nil
      end
    end
  end
end
