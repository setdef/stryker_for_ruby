# frozen_string_literal: true

require_relative "pattern_change"

module Stryker
  module Mutators
    module QuantifierChanges
      def self.of(expression)
        quantifier = expression.quantifier
        return [] unless quantifier

        [PatternChange.new(kind: "Quantifier", offset: quantifier.ts, original: quantifier.text, replacement: "")]
      end
    end
  end
end
