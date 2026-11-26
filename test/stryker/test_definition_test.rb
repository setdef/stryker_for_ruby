# frozen_string_literal: true

require_relative("../support/sample_values")
require_relative("../test_helper")

# Checks that a test holds its ID, name, file, and location, compares by
# value, and survives a round trip through JSON.
class TestDefinitionTest < Minitest::Test
  include SampleValues

  def test_holds_its_members
    assert_equal(
      { id: "Shop::DiscountTest#test_rate", name: "test_rate", file: "test/shop/discount_test.rb", location: },
      test_definition.to_h
    )
  end

  def test_tests_with_equal_members_are_equal
    assert_equal(test_definition, Stryker::Test.new(*test_definition.to_h.values))
  end

  def test_tests_with_different_ids_differ
    refute_equal(test_definition, Stryker::Test.new(**test_definition.to_h, id: "Shop::DiscountTest#test_bulk"))
  end

  def test_a_round_trip_through_json_gives_an_equal_test
    assert_equal(test_definition, Stryker::Test.from_json(test_definition.to_json))
  end

  def test_a_test_with_no_file_or_location_survives_a_round_trip
    test = Stryker::Test.new(id: "Shop::DiscountTest#test_rate", name: "test_rate", file: nil, location: nil)

    assert_equal(test, Stryker::Test.from_json(test.to_json))
  end

  def test_a_missing_location_is_refused
    object = { id: "a", name: "a", file: nil }.transform_keys(&:to_s)

    assert_raises(ArgumentError) { Stryker::Test.from_h(object) }
  end
end
