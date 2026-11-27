# frozen_string_literal: true

module Stryker
  class Pipeline
    class Broadcast
      def initialize(reporters)
        @reporters = reporters
      end

      def call(event)
        @reporters.each { |reporter| reporter.call(event) }
        nil
      end
    end
  end
end
