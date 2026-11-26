# frozen_string_literal: true

module Stryker
  module Runtime
    class Recorder
      def initialize
        @static = Set.new
      end

      def static
        @static.dup
      end

      def record(ids)
        @static.merge(ids)
        nil
      end
    end
  end
end
