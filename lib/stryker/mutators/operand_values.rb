# frozen_string_literal: true

require "prism"

module Stryker
  module Mutators
    module OperandValues
      VALUES = { Prism::OrNode => %w[false], Prism::AndNode => %w[true] }.freeze
      private_constant(:VALUES)

      def self.of(place)
        # true || y is true, which the whole condition already gets as its own
        # mutant, and false && y is false, the other one.
        VALUES[place.parent.class]
      end
    end
  end
end
