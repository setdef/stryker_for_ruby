# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/instrumenter/parse_deadline"

# Checks the time that is left until a deadline.
class ParseDeadlineTest < Minitest::Test
  Deadline = Stryker::Instrumenter::ParseDeadline
  private_constant(:Deadline)

  def test_it_has_nearly_all_its_time_left_at_the_start
    assert_in_delta(60.0, Deadline.new(60.0).left, 1.0)
  end

  def test_it_has_nothing_left_once_the_time_is_up
    assert_in_delta(0.0, Deadline.new(-1.0).left)
  end
end
