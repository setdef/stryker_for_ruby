# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/range_operator"
require_relative("../../support/mutator_sites")

# Runs the mutants of RangeOperator through the instrumenter and checks that
# the program behaves as the original with no mutant active, and as the plain
# mutant with each mutant active.
class RangeOperatorInstrumentedTest < Minitest::Test
  include SiteCase
  include MutatorSites

  def mutator
    Stryker::Mutators::RangeOperator
  end

  def assert_sites(count, source, holder: Prism::RangeNode)
    assert_equal(count, assert_mutator_site(source, mutator, holder:).size)
  end

  def test_an_inclusive_range
    assert_sites(1, "p (1..3).to_a\n")
  end

  def test_an_exclusive_range
    assert_sites(1, "p (1...3).to_a\n")
  end

  def test_a_beginless_range
    assert_sites(1, "p (..5).include?(5)\n")
  end

  def test_a_beginless_exclusive_range
    assert_sites(1, "p (...5).include?(5)\n")
  end

  def test_a_range_that_slices
    assert_sites(1, "p 'hello'[1..3]\n")
  end

  def test_a_range_in_a_when_clause
    cases = ["p(case x when 1..10 then :in else :out end)", "p(case x when 1...10 then :in else :out end)"]

    assert_sites(2, "x = 10\n#{cases.join("\n")}\n")
  end

  def test_a_range_in_a_for_loop
    assert_sites(1, "for i in 1..2\n  p i\nend\n")
  end

  def test_a_range_in_a_pattern
    assert_sites(1, "x = 3\np(case x\n  in 1..3 then :in\n  else :out\n  end)\n", holder: Prism::CaseMatchNode)
  end

  def test_a_range_as_an_argument
    assert_sites(1, "p [1, 2, 3, 4].values_at(1..2)\n")
  end

  def test_a_range_of_strings
    assert_sites(1, "p ('a'..'c').to_a\n")
  end

  def test_a_range_with_an_endless_range_beside_it
    assert_sites(1, "p [(1..3).to_a, (1..).first(2)]\n")
  end
end
