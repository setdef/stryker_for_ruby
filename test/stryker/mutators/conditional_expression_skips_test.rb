# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/conditional_expression"
require_relative("../../support/mutator_case")

# Checks the nodes that ConditionalExpression makes no mutant of, from its
# section of docs/contributors/design/mutators.md, and the rule from #44 for
# the check that a file is the script.
class ConditionalExpressionSkipsTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::ConditionalExpression
  end

  def test_makes_no_mutant_of_a_condition_that_is_true_or_false
    assert_empty(edits("if true then x end\nunless false then x end\nwhile false do x end\nuntil true do x end\n"))
  end

  def test_makes_no_mutant_of_a_condition_that_is_true_or_false_in_parentheses
    assert_empty(edits("if (true) then x end\nx = (false)\n"))
  end

  def test_makes_no_mutant_of_true_or_false_as_a_value
    assert_empty(edits("x = true\ny = false\n"))
  end

  def test_makes_a_mutant_of_a_condition_that_holds_true_and_none_of_the_true
    assert_equal(["if true then x end", "if false then x end"], mutated("if !true then x end"))
  end

  def test_makes_no_mutant_of_a_comparison_that_is_not_one_of_the_six_operators
    assert_empty(edits("a <=> b\na === b\na =~ b\na !~ b\na.eql?(b)\na.==(b)\na.equal?(b)\n"))
  end

  def test_makes_no_mutant_of_a_value_that_is_not_a_comparison_or_a_logical_operator
    assert_empty(edits("x = a\ny = !a\nz = a.b\nw = a & b\n"))
  end

  def test_makes_a_mutant_of_an_expression_condition_that_is_not_a_comparison
    assert_equal(%w[true false], replacements("if a <=> b then x end"))
  end

  def test_makes_no_mutant_of_the_script_guard
    assert_empty(edits("main if __FILE__ == $0"))
  end

  def test_makes_no_mutant_of_the_script_guard_written_with_the_program_name
    assert_empty(edits("main if __FILE__ == $PROGRAM_NAME"))
  end

  def test_makes_no_mutant_of_the_script_guard_written_the_other_way_round
    assert_empty(edits("main if $0 == __FILE__"))
  end

  def test_makes_no_mutant_of_the_script_guard_in_parentheses
    assert_empty(edits("main if (__FILE__ == $0)"))
  end

  def test_makes_no_mutant_of_the_script_guard_as_the_condition_of_an_unless_a_loop_or_a_ternary
    source = [
      "main unless __FILE__ == $0",
      "main while __FILE__ == $0",
      "main until __FILE__ == $0",
      "__FILE__ == $0 ? a : b",
]

    assert_empty(edits(source.join("\n")))
  end

  def test_makes_no_mutant_of_the_script_guard_as_a_value
    assert_empty(edits("script = __FILE__ == $0\nf(__FILE__ == $0)\n"))
  end

  def test_makes_no_mutant_of_an_operator_that_has_the_script_guard_as_an_operand
    source = ["__FILE__ == $0 && main", "__FILE__ == $0 || main", "__FILE__ == $0 and main", "(__FILE__ == $0) or main"]

    assert_empty(edits(source.join("\n")))
  end

  def test_makes_no_mutant_of_an_operator_with_the_script_guard_as_an_operand_that_is_a_condition
    assert_empty(edits("main if __FILE__ == $0 && ready\n"))
  end

  def test_makes_no_mutant_of_a_negation_of_the_script_guard_that_is_a_condition
    assert_empty(edits("main if !(__FILE__ == $0)\nmain unless !(__FILE__ == $0)\nmain if (not __FILE__ == $0)\n"))
  end

  def test_makes_a_mutant_of_an_operand_that_is_not_the_script_guard
    assert_equal(["__FILE__ == $0 && true"], mutated("__FILE__ == $0 && ready == 1"))
  end

  def test_makes_a_mutant_of_the_body_of_a_script_guard
    assert_equal(
      ["if __FILE__ == $0\n  true\nend", "if __FILE__ == $0\n  false\nend"],
      mutated("if __FILE__ == $0\n  a == b\nend")
    )
  end

  def test_makes_a_mutant_of_a_comparison_of_other_values_with_the_names_of_the_guard
    assert_equal(%w[true false], replacements("x = a == $0"))
  end
end
