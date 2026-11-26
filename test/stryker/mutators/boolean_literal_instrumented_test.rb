# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/boolean_literal"
require_relative("../../support/mutator_sites")

# Runs the mutants of BooleanLiteral through the instrumenter and checks that
# the program behaves as the original with no mutant active, and as the plain
# mutant with each mutant active.
class BooleanLiteralInstrumentedTest < Minitest::Test
  include SiteCase
  include MutatorSites

  def mutator
    Stryker::Mutators::BooleanLiteral.new
  end

  def test_true_and_false
    source = "p(true)\np(false)\nx = { on: true, off: false }\np x\n"

    holders = [Prism::TrueNode, Prism::FalseNode, Prism::TrueNode, Prism::FalseNode]

    assert_equal(4, assert_mutator_site(source, mutator, holder: holders).size)
  end

  def test_not_and_the_keyword_not
    source = "x = true\np(!x)\np((not x))\n"

    assert_equal(3, assert_mutator_site(source, mutator, holder: [Prism::TrueNode, Prism::CallNode, Prism::CallNode]).size)
  end

  def test_not_in_a_condition
    source = "[1, 2, 4].each { |n| puts 'odd' if !n.even? }\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::CallNode).size)
  end

  def test_unless_with_an_else
    source = "x = 1\nunless x == 2\n  puts 'a'\nelse\n  puts 'b'\nend\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::UnlessNode).size)
  end

  def test_a_modifier_unless
    source = "x = 1\nputs 'm' unless x == 2\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::UnlessNode).size)
  end

  def test_until
    source = "i = 0\nuntil i >= 3\n  i += 1\nend\np i\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::UntilNode).size)
  end

  def test_a_modifier_until
    source = "i = 0\ni += 1 until i >= 3\np i\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::UntilNode).size)
  end

  def test_a_begin_end_until_that_runs_its_body_first
    source = "i = 0\nbegin\n  i += 1\nend until i >= 3\np i\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::UntilNode).size)
  end

  def test_two_nots_make_one_mutant
    source = "x = 1\np(!!x)\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::CallNode).size)
  end
end
