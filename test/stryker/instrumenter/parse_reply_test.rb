# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/instrumenter/parse_reply"

# Checks the line that a parse worker writes for each plain mutant.
class ParseReplyTest < Minitest::Test
  Reply = Stryker::Instrumenter::ParseReply
  private_constant(:Reply)

  def test_a_line_gives_its_verdict
    assert_equal([true, false], [true, false].map { |valid| Reply.read(Reply.line(valid)) })
  end

  def test_a_line_is_one_line_of_json
    assert_equal("{\"valid\":true}", Reply.line(true))
  end

  def test_anything_else_raises_with_the_line
    lines = ["oops", "", "[]", "7", "{}", "{\"valid\":\"yes\"}"]
    errors = lines.map { |line| assert_raises(ArgumentError) { Reply.read(line) } }

    assert_equal(lines.map { |line| "Not a verdict: #{line}" }, errors.map(&:message))
  end
end
