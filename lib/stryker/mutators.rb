# frozen_string_literal: true

require_relative "mutators/arithmetic_operator"
require_relative "mutators/array_declaration"
require_relative "mutators/assignment_operator"
require_relative "mutators/block_statement"
require_relative "mutators/boolean_literal"
require_relative "mutators/conditional_expression"
require_relative "mutators/equality_operator"
require_relative "mutators/logical_operator"
require_relative "mutators/method_expression"
require_relative "mutators/object_literal"
require_relative "mutators/optional_chaining"
require_relative "mutators/range_operator"
require_relative "mutators/string_literal"
require_relative "mutators/unary_operator"

module Stryker
  module Mutators
    ALL = [
      ArithmeticOperator,
      ArrayDeclaration,
      AssignmentOperator,
      BlockStatement,
      BooleanLiteral,
      ConditionalExpression,
      EqualityOperator,
      LogicalOperator,
      MethodExpression,
      ObjectLiteral,
      OptionalChaining,
      RangeOperator,
      StringLiteral,
      UnaryOperator,
    ].freeze
    public_constant(:ALL)
  end
end
