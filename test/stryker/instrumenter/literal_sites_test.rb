# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/site_case")

# Checks the number, array, hash, and range sites from the literals table of
# the placement design.
class LiteralSitesTest < Minitest::Test
  include SiteCase

  NUMBERS = "p [1, 1.5, 3r, 2i]\n"
  private_constant(:NUMBERS)

  def test_an_integer
    assert_site(NUMBERS, %w[1 2], holder: Prism::IntegerNode)
  end

  def test_a_float
    assert_site(NUMBERS, ["1.5", "2.5"], holder: Prism::FloatNode)
  end

  def test_a_rational
    assert_site(NUMBERS, %w[3r 4r], holder: Prism::RationalNode)
  end

  def test_an_imaginary
    assert_site(NUMBERS, %w[2i 3i], holder: Prism::ImaginaryNode)
  end

  def test_an_integer_as_a_receiver
    assert_site("x = []\n3.times { |i| x << i }\np x\n", %w[3 2], holder: Prism::IntegerNode)
  end

  def test_an_array
    assert_site("p [1, 2]\n", ["[1, 2]", "[]"], holder: Prism::ArrayNode)
  end

  def test_a_hash
    assert_site("p({ a: 1 })\n", ["{ a: 1 }", "{}"], holder: Prism::HashNode)
  end

  def test_an_expression_under_a_splat
    assert_site("a = [1]\np [*a, 3]\n", ["a", "[]", 1], holder: Prism::LocalVariableReadNode)
  end

  def test_a_splat
    assert_site("a = [1]\np [*a, 3]\n", ["*a", "0"], holder: Prism::ArrayNode)
  end

  def test_a_hash_value
    assert_site("p({ a: 1 })\n", %w[1 2], holder: Prism::IntegerNode)
  end

  def test_a_keyword_argument_value
    assert_site("def f(a:)\n  a\nend\np f(a: 1)\n", %w[1 2], holder: Prism::IntegerNode)
  end

  def test_a_hash_pair
    assert_site("p({ a: 1 })\n", ["a: 1", "b: 2"], holder: Prism::HashNode)
  end

  def test_a_calls_keyword_arguments
    assert_site("def f(**k)\n  k\nend\np f(a: 1)\n", ["a: 1", "b: 2"], holder: Prism::CallNode)
  end

  def test_a_range
    assert_site("p (1..3).to_a\n", ["1..3", "1...3"], holder: Prism::RangeNode)
  end

  def test_an_endless_range
    assert_site("p (1..).first(2)\n", ["1..", "2.."], holder: Prism::RangeNode)
  end
end
