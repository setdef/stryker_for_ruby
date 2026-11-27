# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/assignment_operator"
require_relative("../../support/mutator_sites")

# Runs the mutants of AssignmentOperator through the instrumenter and checks
# that the program behaves as the original with no mutant active, and as the
# plain mutant with each mutant active.
class AssignmentOperatorInstrumentedTest < Minitest::Test
  include SiteCase
  include MutatorSites

  BUMP = "p Counter.new.bump\n"
  private_constant(:BUMP)

  def mutator
    Stryker::Mutators::AssignmentOperator
  end

  def assert_sites(count, source, holder)
    assert_equal(count, assert_mutator_site(source, mutator, holder:).size)
  end

  def test_each_operator_with_a_pair
    steps = ["+= 2", "-= 5", "*= 4", "/= 2", "%= 5", "<<= 2", ">>= 1", "&= 5", "|= 2"]
    lines = steps.map { |step| "x #{step}\np x\n" }
    source = "x = 6\n#{lines.join}"

    assert_sites(9, source, Prism::LocalVariableOperatorWriteNode)
  end

  def test_an_or_assignment_to_a_local
    assert_sites(1, "x = nil\nx ||= 5\np x\n", Prism::LocalVariableOrWriteNode)
  end

  def test_an_and_assignment_to_a_local
    assert_sites(1, "x = 1\nx &&= 5\np x\n", Prism::LocalVariableAndWriteNode)
  end

  def test_an_attribute_target
    source = "o = Struct.new(:n).new(1)\no.n += 2\np o.n\n"

    assert_sites(1, source, Prism::CallOperatorWriteNode)
  end

  def test_an_operator_assignment_with_a_heredoc_on_the_right
    source = "def bump\n  x = 1\n  x += <<~A.to_i\n    2\n  A\n  x\nend\np bump\n"

    assert_sites(1, source, Prism::LocalVariableOperatorWriteNode)
  end

  def test_a_class_variable_target
    source = "class Counter\n  @@n = 1\n  def self.bump = (@@n += 2)\nend\np Counter.bump\n"

    assert_sites(1, source, Prism::ParenthesesNode)
  end

  def test_an_instance_variable_target
    source = "class Counter\n  def initialize = @x = 1\n  def bump\n    @x += 2\n    @x\n  end\nend\n#{BUMP}"

    assert_sites(1, source, Prism::DefNode)
  end

  def test_a_global_variable_target
    assert_sites(1, "def bump\n  $x = 1\n  $x += 2\n  $x\nend\np bump\n", Prism::DefNode)
  end

  def test_an_index_target
    source = "def bump\n  h = { a: 1 }\n  h[:a] += 2\n  h[:b] ||= []\n  h\nend\np bump\n"

    assert_sites(2, source, [Prism::DefNode, Prism::IndexOrWriteNode])
  end

  def test_a_safe_navigation_target
    source = "def fill(o)\n  o&.n ||= 4\n  o.n\nend\np fill(Struct.new(:n).new(nil))\n"

    assert_sites(1, source, Prism::DefNode)
  end

  def test_a_constant_path_target
    source = "module Billing\n  RATE = nil\n  def self.set\n    Billing::RATE ||= 5\n  end\nend\nBilling.set\np Billing::RATE\n"

    assert_sites(1, source, Prism::DefNode)
  end
end
