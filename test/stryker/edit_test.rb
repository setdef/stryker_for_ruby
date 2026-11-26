# frozen_string_literal: true

require_relative("../test_helper")
require "prism"
require "stryker/edit"

# Checks that an edit holds its byte range and replacement, compares by value,
# and can be made over a span.
class EditTest < Minitest::Test
  def test_holds_its_members
    edit = Stryker::Edit.new(start_offset: 10, end_offset: 11, replacement: "-")

    assert_equal({ start_offset: 10, end_offset: 11, replacement: "-" }, edit.to_h)
  end

  def test_edits_with_equal_members_are_equal
    assert_equal(Stryker::Edit.new(start_offset: 10, end_offset: 11, replacement: "-"), Stryker::Edit.new(10, 11, "-"))
  end

  def test_edits_with_different_replacements_differ
    refute_equal(Stryker::Edit.new(10, 11, "-"), Stryker::Edit.new(10, 11, "*"))
  end

  def test_is_made_over_the_range_of_a_prism_location
    node = Prism.parse("total = a + b\n").value.statements.body.first.value

    assert_equal(Stryker::Edit.new(8, 13, "a - b"), Stryker::Edit.over(node.location, "a - b"))
  end

  def test_is_made_over_the_range_of_another_edit
    assert_equal(Stryker::Edit.new(10, 11, "*"), Stryker::Edit.over(Stryker::Edit.new(10, 11, "-"), "*"))
  end
end
