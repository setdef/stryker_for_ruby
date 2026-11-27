# frozen_string_literal: true

require_relative("../../test_helper")
require "prism"
require "stryker/instrumenter/heredoc_body"

# Checks what the sites in the placement table can't show: the error for a
# node that isn't a heredoc.
class HeredocBodyTest < Minitest::Test
  def test_the_body_of_a_string_that_is_not_a_heredoc_raises
    string = Prism.parse("?a\n").value.statements.body.first

    error = assert_raises(ArgumentError) { Stryker::Instrumenter::HeredocBody.of(string, [string]) }

    assert_equal("Not a heredoc.", error.message)
  end
end
