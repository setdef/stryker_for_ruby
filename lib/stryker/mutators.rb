# frozen_string_literal: true

require_relative "mutators/arithmetic_operator"
require_relative "mutators/equality_operator"

module Stryker
  module Mutators
    ALL = [ArithmeticOperator.new, EqualityOperator.new].freeze
    public_constant(:ALL)
  end
end
