# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/runtime/served"

# Checks the record of the files that the hook served.
class ServedTest < Minitest::Test
  def test_a_file_the_hook_served_is_recorded
    served = Stryker::Runtime::Served.new

    assert_nil(served.add("/tmp/cache/0.rb"))
    assert_includes(served, "/tmp/cache/0.rb")
  end

  def test_a_file_the_hook_did_not_serve_is_not_recorded
    refute_includes(Stryker::Runtime::Served.new, "/tmp/cache/0.rb")
  end
end
