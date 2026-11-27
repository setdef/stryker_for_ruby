# frozen_string_literal: true

require_relative "pattern_change"

module Stryker
  module Mutators
    module PropertyChanges
      TYPES = %i[property nonproperty].freeze
      private_constant(:TYPES)

      def self.of(expression)
        return [] unless TYPES.include?(expression.type)

        [PatternChange.of(expression, "Property", negated(expression.to_s(:base)))]
      end

      def self.negated(text)
        # \p{^Alpha} is \P{Alpha}, so a caret after the brace is a negation of its own.
        text.match?(/\A\\[pP]\{\^/) ? text.sub("{^", "{") : text.sub(/\A\\[pP]/, &:swapcase)
      end
      private_class_method(:negated)
    end
  end
end
