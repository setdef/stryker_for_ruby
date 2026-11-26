# frozen_string_literal: true

require_relative("../test_helper")
require "stryker/location"

# Checks that a location holds a start and an end position, and compares by
# value.
class LocationTest < Minitest::Test
  def start
    Stryker::Position.new(line: 3, column: 11)
  end

  def finish
    Stryker::Position.new(line: 3, column: 12)
  end

  def test_holds_its_start_and_end
    location = Stryker::Location.new(start:, end: finish)

    assert_equal([start, finish], [location.start, location.end])
  end

  def test_locations_with_equal_positions_are_equal
    assert_equal(Stryker::Location.new(start:, end: finish), Stryker::Location.new(start, finish))
  end

  def test_an_empty_location_starts_where_it_ends
    location = Stryker::Location.new(start:, end: start)

    assert_equal(location.start, location.end)
  end
end
