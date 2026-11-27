# frozen_string_literal: true

require_relative "mutators/arithmetic_operator"
require_relative "mutators/array_declaration"
require_relative "mutators/boolean_literal"
require_relative "mutators/equality_operator"
require_relative "mutators/logical_operator"
require_relative "mutators/object_literal"
require_relative "mutators/string_literal"
require_relative "mutators/unary_operator"

module Stryker
  module Mutators
    ALL = [
      ArithmeticOperator,
      ArrayDeclaration,
      BooleanLiteral,
      EqualityOperator,
      LogicalOperator,
      ObjectLiteral,
      StringLiteral,
      UnaryOperator,
    ].freeze
    public_constant(:ALL)
  end
end
