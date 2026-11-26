# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/site_case")

# Checks the literal sites from the placement table.
class LiteralSitesTest < Minitest::Test
  include SiteCase

  STRINGS = "x = 'a'\ny = 'a'\np [x, x.frozen?, x.equal?(y)]\n"
  private_constant(:STRINGS)

  def test_a_string_with_frozen_string_literals
    assert_site("# frozen_string_literal: true\n#{STRINGS}", ["'a'", "'b'"])
  end

  def test_a_string_with_unfrozen_string_literals
    assert_site("# frozen_string_literal: false\n#{STRINGS}", ["'a'", "'b'"])
  end

  def test_a_string_with_no_magic_comment
    assert_site(STRINGS, ["'a'", "'b'"])
  end

  def test_a_string_as_a_hash_key
    assert_site("h = { 'a' => 1 }\np h\n", ["'a'", "'b'"])
  end

  def test_an_interpolated_string
    assert_site("x = 1\np \"a\#{x}b\"\n", ["\"a\#{x}b\"", "'c'"])
  end

  def test_adjacent_string_literals_on_one_line
    assert_site("p(\"a\" \"b\")\n", ["\"a\" \"b\"", "'c'"])
  end

  def test_a_character_literal
    assert_site("p(?a)\n", ["?a", "?b"])
  end

  def test_a_part_of_adjacent_string_literals_joined_by_a_backslash
    assert_site("x = \"a\" \\\n  \"b\"\np x\n", ['"a"', '"c"'], ['"b"', '"d"'])
  end

  def test_an_expression_inside_an_interpolation
    assert_site("x = 1\np \"a\#{x + 1}b\"\n", ["x + 1", "x - 1"])
  end

  def test_a_word_array
    assert_site("p %w[a b]\n", ["%w[a b]", "%w[c]"])
  end

  def test_a_symbol
    assert_site("p :a\n", [":a", ":b"])
  end

  def test_an_interpolated_symbol
    assert_site("x = 1\np :\"a\#{x}\"\n", [":\"a\#{x}\"", ":b"])
  end

  def test_a_symbol_as_a_block_argument
    assert_site("p [1, 2].map(&:to_s)\n", [":to_s", ":succ"])
  end

  def test_a_label_key_in_a_hash
    assert_site("p({ a: 1 })\n", ["a:", "b:"])
  end

  def test_number_literals
    assert_site("p [1, 1.5, 3r, 2i]\n", %w[1 2], ["1.5", "2.5"], %w[3r 4r], %w[2i 3i])
  end

  def test_an_integer_as_a_receiver
    assert_site("x = []\n3.times { |i| x << i }\np x\n", %w[3 2])
  end

  def test_an_array
    assert_site("p [1, 2]\n", ["[1, 2]", "[]"])
  end

  def test_a_hash
    assert_site("p({ a: 1 })\n", ["{ a: 1 }", "{}"])
  end

  def test_an_expression_under_a_splat
    assert_site("a = [1]\np [*a, 3]\n", ["a", "[]", 1])
  end

  def test_a_splat
    assert_site("a = [1]\np [*a, 3]\n", ["*a", "0"])
  end

  def test_a_hash_value
    assert_site("p({ a: 1 })\n", %w[1 2])
  end

  def test_a_keyword_argument_value
    assert_site("def f(a:)\n  a\nend\np f(a: 1)\n", %w[1 2])
  end

  def test_a_hash_pair
    assert_site("p({ a: 1 })\n", ["a: 1", "b: 2"])
  end

  def test_a_calls_keyword_arguments
    assert_site("def f(**k)\n  k\nend\np f(a: 1)\n", ["a: 1", "b: 2"])
  end

  def test_a_range
    assert_site("p (1..3).to_a\n", ["1..3", "1...3"])
  end

  def test_an_endless_range
    assert_site("p (1..).first(2)\n", ["1..", "2.."])
  end
end
