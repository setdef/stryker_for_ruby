# frozen_string_literal: true

require_relative "test_helper"

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative "../tasks/json_reader"

# tasks/json_reader.rb: a member that is missing or of another kind raises the
# error that the reader was given, with the subject that it was given as the
# start of the message.
class JSONReaderTest < Minitest::Test
  class Trouble < StandardError; end
  private_constant(:Trouble)

  def test_a_member_of_the_kind_asked_for_is_read
    reader = JSONReader.new(JSON.parse('{"a": "x", "b": 2, "c": null, "d": [{}]}'), "the report", Trouble)
    read = [reader.string("a"), reader.integer("b"), reader.string_or_nil("c"), reader.objects("d")]

    assert_equal(["x", 2, nil, [{}]], read)
  end

  def test_a_missing_member_raises_the_error_with_the_subject
    error = assert_raises(Trouble) { JSONReader.new({}, "the report holds a smell", Trouble).string("type") }

    assert_equal('the report holds a smell with no "type"', error.message)
  end

  def test_a_member_of_another_kind_raises_the_error_with_the_subject
    reader = JSONReader.new(JSON.parse('{"line": "4"}'), "the report holds a spot", Trouble)
    error = assert_raises(Trouble) { reader.integer("line") }

    assert_equal('the report holds a spot with "line" as "4", not an Integer', error.message)
  end
end
