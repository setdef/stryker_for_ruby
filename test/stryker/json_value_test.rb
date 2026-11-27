# frozen_string_literal: true

require_relative("../support/sample_values")
require_relative("../test_helper")

# Checks that the values convert to JSON and back with the standard library's
# JSON.generate and JSON.parse, and refuse text that isn't a value.
class JsonValueTest < Minitest::Test
  include SampleValues

  def test_a_value_becomes_a_hash_with_a_string_key_for_each_member
    assert_equal({ line: 8, column: 3 }.transform_keys(&:to_s), position.as_json)
  end

  def test_a_member_that_holds_a_value_holds_its_hash
    assert_equal({ line: 8, column: 3 }.transform_keys(&:to_s), location.as_json["start"])
  end

  def test_a_member_that_holds_an_array_of_values_holds_an_array_of_hashes
    assert_equal(%w[failed passed], dry_run_result.as_json["results"].map { |result| result["status"] })
  end

  def test_a_member_that_holds_a_hash_is_left_as_it_is
    assert_equal({ "Shop::DiscountTest#test_rate": [3, 4] }.transform_keys(&:to_s), dry_run_result.as_json["buckets"])
  end

  def test_a_value_ignores_the_options_that_active_support_passes
    assert_equal(position.as_json, position.as_json({ only: [:line] }.freeze))
  end

  def test_a_value_takes_the_nil_that_active_support_passes_by_default
    assert_equal(position.as_json, position.as_json(nil))
  end

  def test_a_value_is_one_line_of_json
    assert_equal('{"line":8,"column":3}', position.to_json)
  end

  def test_a_value_inside_a_larger_document_is_written_as_its_object
    assert_equal('{"at":{"line":8,"column":3}}', JSON.generate({ at: position }))
  end

  def test_text_becomes_the_value_that_wrote_it
    assert_equal(position, Stryker::Position.from_json('{"line":8,"column":3}'))
  end

  def test_a_hash_becomes_the_value_that_wrote_it
    assert_equal(position, Stryker::Position.from_h({ line: 8, column: 3 }.transform_keys(&:to_s)))
  end

  def test_text_that_is_not_json_is_refused
    assert_raises(JSON::ParserError) { Stryker::Position.from_json("{") }
  end

  def test_text_that_is_not_an_object_is_refused
    error = assert_raises(ArgumentError) { Stryker::Position.from_json("[8,3]") }

    assert_equal("expected a JSON object, got Array", error.message)
  end

  def test_a_string_that_is_not_valid_utf_8_is_written_with_replacement_characters
    assert_equal(["bad \u{FFFD} byte"], Stryker::JsonValue.plain(["bad \xFF byte"]))
  end

  def test_a_hash_key_that_is_not_valid_utf_8_is_written_with_a_replacement_character
    assert_equal([["k\u{FFFD}", 1]].to_h, Stryker::JsonValue.plain([["k\xFF", 1]].to_h))
  end

  def test_a_missing_member_is_refused
    assert_raises(ArgumentError) { Stryker::Position.from_json('{"line":8}') }
  end

  def test_a_key_that_is_no_member_is_refused
    assert_raises(ArgumentError) { Stryker::Position.from_json('{"line":8,"column":3,"row":1}') }
  end
end
