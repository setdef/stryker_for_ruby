# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/assignment_operator"
require_relative("../../support/mutator_case")

# Checks the assignments that AssignmentOperator makes no mutant of, from its
# section of docs/contributors/design/mutators.md.
class AssignmentOperatorSkipsTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::AssignmentOperator
  end

  def test_makes_no_mutant_of_an_operator_that_has_no_pair
    assert_empty(edits("x **= 2\nx ^= 2\n"))
  end

  def test_makes_no_mutant_of_a_plain_assignment
    assert_empty(edits("x = 1\n@x = 1\nx, y = 1, 2\nx.y = 1\nx[y] = 1\n"))
  end

  def test_makes_no_mutant_of_an_operator_assignment_of_a_string
    assert_empty(edits(%(report += "line"\nname *= 'x'\nname %= "a"\n)))
  end

  def test_makes_no_mutant_of_an_operator_assignment_of_an_interpolated_string
    assert_empty(edits("report << 'a'\nreport += \"line \#{n}\"\n"))
  end

  def test_makes_no_mutant_of_an_operator_assignment_of_a_command
    assert_empty(edits("out += `ls`\nout += %x(ls \#{dir})\n"))
  end

  def test_makes_no_mutant_of_an_operator_assignment_of_a_heredoc
    assert_empty(edits("text += <<~TEXT\n  hello\nTEXT\n"))
  end

  def test_makes_no_mutant_of_every_operator_except_the_logical_ones_when_the_value_is_a_string
    operators = ["+=", "-=", "*=", "/=", "%=", "<<=", ">>=", "&=", "|="]

    assert_empty(operators.flat_map { |operator| edits("x #{operator} 'a'") })
  end

  def test_keeps_the_pair_of_an_or_assignment_when_the_value_is_a_string
    assert_equal(["name &&= 'Guest'"], mutated("name ||= 'Guest'"))
  end

  def test_keeps_the_pair_of_an_and_assignment_when_the_value_is_a_string
    assert_equal(["name ||= \"Guest\#{n}\""], mutated("name &&= \"Guest\#{n}\""))
  end

  def test_makes_a_mutant_when_a_string_is_only_part_of_the_value
    assert_equal(["x -= 'a'.size"], mutated("x += 'a'.size"))
  end

  def test_makes_a_mutant_when_the_value_is_a_variable_that_may_hold_a_string
    assert_equal(["x -= y"], mutated("x += y"))
  end

  def test_makes_a_mutant_when_the_value_is_a_symbol_or_a_number
    assert_equal(["x -= :a", "x /= 2.5"], mutated("x += :a") + mutated("x *= 2.5"))
  end

  def test_makes_no_mutant_of_a_binary_operator_that_is_not_an_assignment
    assert_empty(edits("x + 1\nx || y\nx && y\nx << 1\n"))
  end
end
