# frozen_string_literal: true

require_relative("../../support/minitest_project")

# How the Minitest adapter words the failure of a test in a file whose name
# isn't valid UTF-8, with a small project loaded into this process.
class MinitestBrokenPathTest < Minitest::Test
  include MinitestProject

  # The backtrace line of a test in a file whose name isn't valid UTF-8, which
  # Minitest matches with a regexp and which raises for such a line.
  BROKEN_PATH = { "test/broken_path_test.rb": <<~'RUBY' }.freeze
    class BrokenPathTest < Minitest::Test
      def test_fails
        failure = Minitest::Assertion.new("Expected 1, got 2.")
        failure.set_backtrace(["test/caf\xE9_test.rb:3:in 'test_fails'"])
        raise(failure)
      end

      def test_raises
        error = RuntimeError.new("Raised in the test.")
        error.set_backtrace(["test/caf\xE9_test.rb:7:in 'test_raises'"])
        raise(error)
      end
    end
  RUBY
  PHRASES = /Expected 1, got 2\.|Raised in the test\./
  private_constant(:BROKEN_PATH, :PHRASES)

  def test_a_test_that_fails_in_a_file_whose_name_is_not_utf8_fails_with_its_message
    filter = Minitest.backtrace_filter
    results = run_ids(loaded(BROKEN_PATH), "BrokenPathTest#test_fails", "BrokenPathTest#test_raises")
    messages = results.map { |result| [result.status, result.failure_message.scan(PHRASES)] }

    assert_equal([["failed", ["Expected 1, got 2."]], ["failed", ["Raised in the test."]]], messages)
    assert_same(filter, Minitest.backtrace_filter)
  end
end
