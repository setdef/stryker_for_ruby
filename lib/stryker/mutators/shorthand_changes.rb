# frozen_string_literal: true

require_relative "pattern_change"

module Stryker
  module Mutators
    module ShorthandChanges
      TOKENS = %i[digit nondigit space nonspace word nonword].freeze
      private_constant(:TOKENS)

      def self.of(expression)
        return [] unless expression.type == :type && TOKENS.include?(expression.token)

        [PatternChange.of(expression, "Character class shorthand", expression.to_s(:base).swapcase)]
      end
    end
  end
end
