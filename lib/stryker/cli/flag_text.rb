# frozen_string_literal: true

module Stryker
  class CLI
    module FlagText
      NUMBER = /\A-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\z/
      WHOLE = /\A-?\d+\z/
      NONE = "none"
      OUTSIDE_BRACES = /,(?![^{]*\})/
      private_constant(:NUMBER, :WHOLE, :NONE, :OUTSIDE_BRACES)

      def self.text(word)
        word
      end

      def self.number(word)
        return Integer(word, 10) if WHOLE.match?(word)

        NUMBER.match?(word) ? Float(word) : word
      end

      def self.number_or_none(word)
        (word == NONE) ? nil : number(word)
      end

      def self.list(word)
        word.split(OUTSIDE_BRACES).reject(&:empty?)
      end
    end
  end
end
