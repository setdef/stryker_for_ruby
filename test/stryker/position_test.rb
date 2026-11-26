# frozen_string_literal: true

require_relative("../test_helper")
require "stryker/position"

# Checks that a position holds a line and a column, and compares by value.
class PositionTest < Minitest::Test
  def test_holds_its_line_and_column
    position = Stryker::Position.new(line: 3, column: 11)

    assert_equal([3, 11], [position.line, position.column])
  end

  def test_positions_with_the_same_line_and_column_are_equal
    assert_equal(Stryker::Position.new(line: 3, column: 11), Stryker::Position.new(3, 11))
  end

  def test_positions_on_different_columns_differ
    refute_equal(Stryker::Position.new(line: 3, column: 11), Stryker::Position.new(line: 3, column: 12))
  end
end
