# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/site_case")

# Checks the operator sites, and the sites with several mutants, from the
# placement table.
class OperatorSitesTest < Minitest::Test
  include SiteCase

  def test_a_binary_operator
    assert_site("a = 2\nb = 3\np(a + b)\n", ["a + b", "a - b"], holder: Prism::CallNode)
  end

  def test_a_comparison
    assert_site("a = 2\nb = 3\np(a < b)\n", ["a < b", "a >= b"], holder: Prism::CallNode)
  end

  def test_a_negated_match
    assert_site("s = 'ab'\np(s !~ /a/)\n", ["s !~ /a/", "s =~ /a/"], holder: Prism::CallNode)
  end

  def test_a_binary_operator_as_a_command_argument_with_an_operator_after_it
    assert_site("a = 6\nb = 2\nputs a * b + 1\n", ["a * b", "a / b"], holder: Prism::CallNode)
  end

  def test_a_logical_and
    assert_site("a = true\nb = false\np(a && b)\n", ["a && b", "a || b"], holder: Prism::AndNode)
  end

  def test_a_logical_or
    assert_site("a = true\nb = false\np(a || b)\n", ["a || b", "a && b"], holder: Prism::OrNode)
  end

  def test_the_keyword_and
    assert_site("a = true\nb = false\nx = (a and b)\np x\n", ["a and b", "a or b"], holder: Prism::AndNode)
  end

  def test_the_keyword_or
    assert_site("a = true\nb = false\nx = (a or b)\np x\n", ["a or b", "a and b"], holder: Prism::OrNode)
  end

  def test_a_unary_minus
    assert_site("a = 5\np(-a)\n", ["-a", "+a"], holder: Prism::CallNode)
  end

  def test_a_unary_complement
    assert_site("a = 5\np(~a)\n", ["~a", "-a"], holder: Prism::CallNode)
  end

  def test_a_unary_not
    assert_site("a = true\np(!a)\n", ["!a", "a"], holder: Prism::CallNode)
  end

  def test_the_keyword_not
    assert_site("a = true\np((not a))\n", ["not a", "a"], holder: Prism::CallNode)
  end

  def test_a_unary_minus_on_a_power
    assert_site("a = 3\np(-a ** 2)\n", ["-a ** 2", "a ** 2"], holder: Prism::CallNode)
  end

  def test_a_negative_integer_literal
    assert_site("p(-1)\n", ["-1", "1"], holder: Prism::IntegerNode)
  end

  def test_an_operator_with_three_mutants
    assert_site("a = 2\nb = 3\np(a + b)\n", ["a + b", "a - b"], ["a + b", "a * b"], ["a + b", "0"], holder: Prism::CallNode)
  end

  def test_a_condition_with_four_mutants
    source = "p([0, 1, 2].map { |a| a > 1 })\n"

    assert_site(source, ["a > 1", "true"], ["a > 1", "false"], ["a > 1", "a < 1"], ["a > 1", "a >= 1"], holder: Prism::CallNode)
  end

  def test_an_operator_inside_another_mutants_site
    assert_site("a = 1\nb = 2\nc = 3\np(a + b * c)\n", ["a + b * c", "a - b * c"], ["b * c", "b / c"], holder: Prism::CallNode)
  end
end
