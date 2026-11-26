# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/logical_operator"
require_relative("../../support/mutator_sites")

# Runs the mutants of LogicalOperator through the instrumenter and checks that
# the program behaves as the original with no mutant active, and as the plain
# mutant with each mutant active.
class LogicalOperatorInstrumentedTest < Minitest::Test
  include SiteCase
  include MutatorSites

  def mutator
    Stryker::Mutators::LogicalOperator
  end

  def test_and_and_the_keyword_and
    source = "a = true\nb = false\np(a && b)\nx = (a and b)\np x\n"

    assert_equal(2, assert_mutator_site(source, mutator, holder: Prism::AndNode).size)
  end

  def test_or_and_the_keyword_or
    source = "a = true\nb = false\np(a || b)\nx = (a or b)\np x\n"

    assert_equal(2, assert_mutator_site(source, mutator, holder: Prism::OrNode).size)
  end

  def test_a_chain_of_ors_groups_its_first_operands_in_the_mutant
    # With the text a || b && c, the mutant would give the original's answer.
    source = "a = true\nb = false\nc = false\np(a || b || c)\n"

    assert_equal(2, assert_mutator_site(source, mutator, holder: Prism::OrNode).size)
  end

  def test_a_chain_of_ands
    source = "a = true\nb = false\nc = true\np(a && b && c)\n"

    assert_equal(2, assert_mutator_site(source, mutator, holder: Prism::AndNode).size)
  end

  def test_an_and_inside_an_or
    source = "[[true, true, false], [false, true, false]].each { |a, b, c| p(a || b && c) }\n"

    assert_equal(2, assert_mutator_site(source, mutator, holder: [Prism::OrNode, Prism::AndNode]).size)
  end

  def test_an_operator_across_lines
    source = "a = true\nb = false\np(a &&\n  b)\n"

    assert_equal(1, assert_mutator_site(source, mutator, holder: Prism::AndNode).size)
  end

  def test_a_condition_that_holds_a_logical_operator
    source = "[[false, false], [true, false]].each do |a, b|\n  puts 'yes' if a && !b\n  puts 'no' unless a || b\nend\n"

    assert_equal(2, assert_mutator_site(source, mutator, holder: [Prism::AndNode, Prism::OrNode]).size)
  end
end
