# frozen_string_literal: true

require_relative("../../test_helper")
require "stringio"
require "stryker/runtime"

# Checks the line that the runtime writes on a Ruby older than 4.0. The tests
# pass the version and the stream in, because the test process has one Ruby,
# and process_test.rb checks that loading the runtime on it writes the line
# only where it belongs.
class OlderRubyTest < Minitest::Test
  PAGE = "https://github.com/setdef/stryker_for_ruby/blob/trunk/docs/older-ruby.md"
  private_constant(:PAGE)

  def stream
    @stream ||= StringIO.new
  end

  def test_ruby_3_3_gets_one_line_that_names_its_version_and_the_page
    Stryker::Runtime::OlderRuby.notify("3.3.11", stream)

    expected = "Stryker (for Ruby) doesn't support Ruby 3.3.11, which is older than 4.0. " \
      "Problems found on Ruby 3.3 and 3.4 are listed at #{PAGE}\n"

    assert_equal(expected, stream.string)
  end

  def test_ruby_3_4_gets_the_line_too
    Stryker::Runtime::OlderRuby.notify("3.4.13", stream)

    assert_includes(stream.string, "Ruby 3.4.13")
  end

  def test_ruby_4_0_gets_none
    Stryker::Runtime::OlderRuby.notify("4.0.10", stream)

    assert_empty(stream.string)
  end

  # A later Ruby has a later version number, and a first number of 10 is
  # later than 4 although "10" sorts before "4" as text.
  def test_a_first_number_of_ten_is_not_older_than_four
    Stryker::Runtime::OlderRuby.notify("10.0.0", stream)

    assert_empty(stream.string)
  end

  def test_it_returns_nil
    assert_nil(Stryker::Runtime::OlderRuby.notify("3.3.11", stream))
  end

  def test_the_constants_are_private
    assert_empty(Stryker::Runtime::OlderRuby.constants)
  end
end
