# frozen_string_literal: true

require_relative "mutators/arithmetic_operator"

module Stryker
  module Mutators
    ALL = [ArithmeticOperator.new].freeze
    public_constant(:ALL)
  end
end
