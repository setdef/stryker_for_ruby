# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/site_case")

# Checks the string and symbol sites from the literals table of the placement
# design.
class StringSitesTest < Minitest::Test
  include SiteCase

  STRINGS = "x = 'a'\ny = 'a'\np [x, x.frozen?, x.equal?(y)]\n"
  private_constant(:STRINGS)

  def test_a_string_with_frozen_string_literals
    assert_site("# frozen_string_literal: true\n#{STRINGS}", ["'a'", "'b'"], holder: Prism::StringNode)
  end

  def test_a_string_with_unfrozen_string_literals
    assert_site("# frozen_string_literal: false\n#{STRINGS}", ["'a'", "'b'"], holder: Prism::StringNode)
  end

  def test_a_string_with_no_magic_comment
    assert_site(STRINGS, ["'a'", "'b'"], holder: Prism::StringNode)
  end

  def test_a_string_as_a_hash_key
    assert_site("h = { 'a' => 1 }\np h\n", ["'a'", "'b'"], holder: Prism::StringNode)
  end

  def test_an_interpolated_string
    assert_site("x = 1\np \"a\#{x}b\"\n", ["\"a\#{x}b\"", "'c'"], holder: Prism::InterpolatedStringNode)
  end

  def test_an_interpolated_instance_variable
    assert_site("@x = 1\n@y = 2\np \"\#@x\"\n", ["@x", "@y", 1], holder: Prism::InterpolatedStringNode)
  end

  def test_an_interpolated_global_variable
    assert_site("$x = 1\n$y = 2\np \"\#$x\"\n", ["$x", "$y", 1], holder: Prism::InterpolatedStringNode)
  end

  def test_a_part_of_an_interpolated_command_string
    assert_site("x = 'a'\np `echo \#{x}b`\n", %w[b c], holder: Prism::CallNode)
  end

  def test_adjacent_string_literals_on_one_line
    assert_site("p(\"a\" \"b\")\n", ["\"a\" \"b\"", "'c'"], holder: Prism::InterpolatedStringNode)
  end

  def test_a_character_literal
    assert_site("p(?a)\n", ["?a", "?b"], holder: Prism::StringNode)
  end

  def test_a_part_of_adjacent_string_literals_joined_by_a_backslash
    assert_site("x = \"a\" \\\n  \"b\"\np x\n", ['"a"', '"c"'], ['"b"', '"d"'], holder: Prism::InterpolatedStringNode)
  end

  def test_an_expression_inside_an_interpolation
    assert_site("x = 1\np \"a\#{x + 1}b\"\n", ["x + 1", "x - 1"], holder: Prism::CallNode)
  end

  def test_a_word_array
    assert_site("p %w[a b]\n", ["%w[a b]", "%w[c]"], holder: Prism::ArrayNode)
  end

  def test_a_word_of_a_word_array
    assert_site("p %w[a b]\n", %w[a c], holder: Prism::ArrayNode)
  end

  def test_a_word_of_a_symbol_array
    assert_site("p %i[a b]\n", %w[a c], holder: Prism::ArrayNode)
  end

  def test_a_symbol
    assert_site("p :a\n", [":a", ":b"], holder: Prism::SymbolNode)
  end

  def test_an_interpolated_symbol
    assert_site("x = 1\np :\"a\#{x}\"\n", [":\"a\#{x}\"", ":b"], holder: Prism::InterpolatedSymbolNode)
  end

  def test_a_symbol_as_a_block_argument
    assert_site("p [1, 2].map(&:to_s)\n", [":to_s", ":succ"], holder: Prism::SymbolNode)
  end

  def test_a_label_key_in_a_hash
    assert_site("p({ a: 1 })\n", ["a:", "b:"], holder: Prism::HashNode)
  end
end
