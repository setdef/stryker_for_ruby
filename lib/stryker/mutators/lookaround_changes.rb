# frozen_string_literal: true

require_relative "pattern_change"

module Stryker
  module Mutators
    module LookaroundChanges
      OPENING = /\A\(\?<?[=!]/
      private_constant(:OPENING)

      def self.of(expression)
        return [] unless expression.type == :assertion

        [PatternChange.of(expression, "Lookaround", negated(expression.to_s(:base)))]
      end

      def self.negated(text)
        text.sub(OPENING) { |opening| opening.tr("=!", "!=") }
      end
      private_class_method(:negated)
    end
  end
end
