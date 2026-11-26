# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/boolean_literal"
require "stryker/mutators/logical_operator"
require_relative("../../support/mutator_case")

# Checks that LogicalOperator and BooleanLiteral make no mutant of a node whose
# condition or operand is the check that a file is the script that runs, from
# the sites that get no mutant in docs/design/mutators.md. Such a mutant runs
# the file's script code inside the test process.
class ScriptGuardSitesTest < Minitest::Test
  include MutatorCase

  def replacements_of(mutator, source)
    edits = nodes_of(Prism.parse(source).value).flat_map { |node, ancestors| mutator.edits(node, ancestors) }
    edits.map(&:replacement)
  end

  def logical(source)
    replacements_of(Stryker::Mutators::LogicalOperator, source)
  end

  def boolean(source)
    replacements_of(Stryker::Mutators::BooleanLiteral, source)
  end

  def test_logical_operator_makes_no_mutant_of_an_operator_that_has_the_check_as_an_operand
    sources = ["__FILE__ == $0 and main", "main and __FILE__ == $0", "$0 == __FILE__ or main", "main || $0 == __FILE__"]

    assert_empty(sources.flat_map { |source| logical(source) })
  end

  def test_logical_operator_makes_no_mutant_of_an_operator_that_has_the_check_in_parentheses_as_an_operand
    assert_empty(["(__FILE__ == $0) && main", "main || ((__FILE__ == $0))"].flat_map { |source| logical(source) })
  end

  def test_logical_operator_makes_a_mutant_of_an_operator_that_has_the_check_deeper_inside_it
    mutants = logical("a && (b || (c && __FILE__ == $0))")

    assert_equal(["a || (b || (c && __FILE__ == $0))", "b && (c && __FILE__ == $0)"], mutants)
  end

  def test_logical_operator_makes_a_mutant_of_an_operator_that_has_another_comparison_as_an_operand
    mutants = logical("__FILE__ == name && main") + logical("$0 == $PROGRAM_NAME and main")

    assert_equal(["__FILE__ == name || main", "$0 == $PROGRAM_NAME or main"], mutants)
  end

  def test_boolean_literal_makes_no_mutant_of_an_unless_or_an_until_whose_condition_is_the_check
    sources = ["unless __FILE__ == $0\n  a\nend\n", "until $0 == __FILE__\n  a\nend\n"]
    modifiers = ["a unless __FILE__ == $0", "a until $0 == __FILE__"]

    assert_empty((sources + modifiers).flat_map { |source| boolean(source) })
  end

  def test_boolean_literal_makes_no_mutant_of_an_unless_whose_condition_is_the_check_in_parentheses
    assert_empty(boolean("unless (__FILE__ == $0)\n  a\nend\n"))
  end

  def test_boolean_literal_makes_no_mutant_of_a_negation_whose_operand_is_the_check
    sources = ["!(__FILE__ == $0)", "not(__FILE__ == $0)", "!($PROGRAM_NAME == __FILE__)"]

    assert_empty(sources.flat_map { |source| boolean(source) })
  end

  def test_boolean_literal_makes_a_mutant_of_an_unless_or_a_negation_whose_condition_is_another_comparison
    sources = ["unless __FILE__ == name\n  a\nend\n", "!(a == b)", "unless a == $0\n  a\nend\n"]

    assert_equal([["if"], ["(a == b)"], ["if"]], sources.map { |source| boolean(source) })
  end

  def test_boolean_literal_makes_a_mutant_of_a_literal_inside_a_node_that_the_check_decides
    assert_equal(%w[false true], boolean("unless __FILE__ == $0\n  a(true)\nelse\n  b(false)\nend\n"))
  end
end
