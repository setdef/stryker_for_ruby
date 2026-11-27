# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/conditional_expression"
require_relative("../../support/mutator_sites")

# Runs the mutants of ConditionalExpression through the instrumenter and checks
# that the program behaves as the original with no mutant active, and as the
# plain mutant with each mutant active.
class ConditionalExpressionInstrumentedTest < Minitest::Test
  include SiteCase
  include MutatorSites

  PICKS = "p [pick(0), pick(2)]\n"
  private_constant(:PICKS)

  THREE_PICKS = "p [pick(0), pick(2), pick(3)]\n"
  private_constant(:THREE_PICKS)

  def mutator
    Stryker::Mutators::ConditionalExpression
  end

  def assert_sites(count, source, holder: Prism::CallNode)
    assert_equal(count, assert_mutator_site(source, mutator, holder:).size)
  end

  def test_the_condition_of_an_if
    assert_sites(2, "def pick(x)\n  if x > 1 then :big else :small end\nend\n#{PICKS}")
  end

  def test_the_conditions_of_an_if_with_an_elsif
    source = "def pick(x)\n  if x > 2 then :big elsif x > 1 then :mid else :small end\nend\n#{THREE_PICKS}"

    assert_sites(4, source)
  end

  def test_the_condition_of_an_unless
    assert_sites(2, "def pick(x)\n  unless x > 1 then :small else :big end\nend\n#{PICKS}")
  end

  def test_the_condition_of_a_ternary
    assert_sites(2, "def pick(x)\n  x > 1 ? :big : :small\nend\n#{PICKS}")
  end

  def test_the_condition_of_a_modifier_if
    assert_sites(2, "def pick(x)\n  r = []\n  r << :big if x > 1\n  r\nend\n#{PICKS}")
  end

  def test_the_condition_of_an_expression_that_is_not_a_comparison
    source = "def pick(x)\n  if x then :yes else :no end\nend\np [pick(nil), pick(1)]\n"

    assert_sites(2, source, holder: Prism::LocalVariableReadNode)
  end

  def test_the_condition_in_parentheses
    assert_sites(2, "def pick(x)\n  if (x > 1) then :big else :small end\nend\n#{PICKS}")
  end

  def test_the_guard_of_a_case_in
    source = "def pick(x)\n  case x\n  in Integer => n if n > 1 then :big\n  else :small\n  end\nend\n#{PICKS}"

    assert_sites(2, source)
  end

  def test_the_condition_of_a_while_loop
    assert_sites(1, "i = 0\nwhile i < 3\n  i += 1\nend\np i\n")
  end

  def test_the_condition_of_an_until_loop
    assert_sites(1, "i = 0\nuntil i >= 3\n  i += 1\nend\np i\n")
  end

  def test_the_condition_of_a_modifier_while
    assert_sites(1, "i = 0\ni += 1 while i < 3\np i\n")
  end

  def test_the_condition_of_a_begin_end_while_that_runs_its_body_first
    assert_sites(1, "i = 0\nbegin\n  i += 1\nend while i < 3\np i\n")
  end

  def test_a_comparison_that_is_a_value
    assert_sites(2, "def lt(a, b) = a < b\np [lt(1, 2), lt(2, 1)]\n")
  end

  def test_a_comparison_as_an_operand_of_or
    source = "def f(a, b) = a || b == 1\np [f(nil, 1), f(nil, 2)]\n"

    assert_sites(3, source, holder: [Prism::OrNode, Prism::OrNode, Prism::CallNode])
  end

  def test_a_comparison_as_an_operand_of_and
    source = "def g(a, b) = a && b == 1\np [g(1, 1), g(1, 2)]\n"

    assert_sites(3, source, holder: [Prism::AndNode, Prism::AndNode, Prism::CallNode])
  end

  def test_the_operands_of_a_keyword_and_that_is_a_condition
    source = "def pick(x)\n  if x > 1 and x < 3 then :two else :other end\nend\n#{THREE_PICKS}"

    assert_sites(4, source, holder: [Prism::AndNode, Prism::AndNode, Prism::CallNode, Prism::CallNode])
  end
end
