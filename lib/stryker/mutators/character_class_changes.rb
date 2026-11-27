# frozen_string_literal: true

require "regexp_parser"
require_relative "pattern_change"

module Stryker
  module Mutators
    module CharacterClassChanges
      def self.of(expression)
        return [] unless expression.is_a?(Regexp::Expression::CharacterSet)

        [PatternChange.of(expression, "Character class", negated(expression))]
      end

      def self.negated(expression)
        text = expression.to_s(:base)
        expression.negative? ? text.sub("[^", "[") : text.sub("[", "[^")
      end
      private_class_method(:negated)
    end
  end
end
