# frozen_string_literal: true

require_relative("../test_helper")
require "stryker/mutators"
require "stryker/mutators/walk"

# Checks the list of built mutators: that it follows the order of the
# catalog's table, and that a walk uses it when it is given no other.
class MutatorsTest < Minitest::Test
  CATALOG = %w[
    ArithmeticOperator
    ArrayDeclaration
    AssignmentOperator
    BlockStatement
    BooleanLiteral
    CallExpression
    ConditionalExpression
    EqualityOperator
    LogicalOperator
    MethodExpression
    ObjectLiteral
    OptionalChaining
    RangeOperator
    Regex
    StringLiteral
    UnaryOperator
  ].freeze
  private_constant(:CATALOG)

  def test_lists_the_mutators_in_the_order_of_the_catalogs_table
    assert_equal(CATALOG, Stryker::Mutators::ALL.map(&:name))
  end

  def test_lists_call_expression_as_the_one_fallback
    assert_equal([Stryker::Mutators::CallExpression], Stryker::Mutators::FALLBACKS)
  end

  def test_a_walk_asks_every_mutator_in_the_list_when_given_none
    result = Prism.parse("total = a + b\n")

    assert_equal(["a - b"], Stryker::Mutators::Walk.new(file: "lib/a.rb", result:).mutants.map(&:replacement))
  end
end
