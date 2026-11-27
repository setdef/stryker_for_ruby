# frozen_string_literal: true

module Stryker
  module Reporters
    class Ink
      CODES = {
        red: 31, green: 32, yellow: 33, cyan: 36, grey: 90, red_bright: 91, green_bright: 92, blue_bright: 94
      }.freeze
      private_constant(:CODES)

      def initialize(enabled:)
        @enabled = enabled
      end

      def paint(color, text)
        code = CODES.fetch(color) { raise(ArgumentError, "unknown color #{color.inspect}") }
        @enabled ? "\e[#{code}m#{text}\e[39m" : text
      end
    end
  end
end
