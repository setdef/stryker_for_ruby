# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/reporters/column_group"
require "stryker/reporters/ink"

# Checks that a group of columns says it needs one.
class ColumnGroupTest < Minitest::Test
  def test_refuses_a_group_with_no_column
    error = assert_raises(ArgumentError) { Stryker::Reporters::ColumnGroup.new("scores", Stryker::Reporters::Ink.new(enabled: false)) }

    assert_equal("a group needs a column", error.message)
  end
end
