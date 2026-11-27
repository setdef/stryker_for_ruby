# frozen_string_literal: true

require "test_helper"

class GreeterTest < Minitest::Test
  def test_call
    assert_equal("Hello, Ada!", Greeter.call("Ada"))
  end
end
