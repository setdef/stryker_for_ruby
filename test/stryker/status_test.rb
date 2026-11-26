# frozen_string_literal: true

require_relative("../test_helper")
require "stryker/status"

# Checks that a status is accepted when it is in the list, and refused, with a
# message that names it, when it isn't.
class StatusTest < Minitest::Test
  def test_a_status_in_the_list_is_accepted
    assert_nil(Stryker::Status.check("failed", %w[passed failed], "test"))
  end

  def test_a_status_that_is_not_in_the_list_is_refused
    error = assert_raises(ArgumentError) { Stryker::Status.check("failure", %w[passed failed], "test") }

    assert_equal('unknown test status "failure", expected one of passed, failed', error.message)
  end

  def test_a_symbol_is_not_a_string_in_the_list
    assert_raises(ArgumentError) { Stryker::Status.check(:failed, %w[passed failed], "test") }
  end
end
