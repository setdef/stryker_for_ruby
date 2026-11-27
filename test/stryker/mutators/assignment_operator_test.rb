# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/assignment_operator"
require_relative("../../support/mutator_case")

# Checks the pairs of AssignmentOperator and the nodes it makes no mutant of,
# from its section of docs/contributors/design/mutators.md.
class AssignmentOperatorTest < Minitest::Test
  include MutatorCase

  PAIRS = {
    "+=": "-=",
    "-=": "+=",
    "*=": "/=",
    "/=": "*=",
    "%=": "*=",
    "<<=": ">>=",
    ">>=": "<<=",
    "&=": "|=",
    "|=": "&=",
    "||=": "&&=",
    "&&=": "||=",
  }.freeze
  private_constant(:PAIRS)

  def mutator
    Stryker::Mutators::AssignmentOperator
  end

  def test_is_named_for_the_report
    assert_equal("AssignmentOperator", mutator.name)
  end

  def test_each_operator_becomes_its_pair
    PAIRS.each do |original, mutant|
      assert_equal(["x #{mutant} y"], mutated("x #{original} y"), "x #{original} y")
    end
  end

  def test_the_edit_covers_the_whole_assignment
    edit = edits("count += 1\n").first

    assert_equal([0, 10, "count -= 1"], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_the_mutant_is_the_whole_file_with_the_operator_changed
    assert_equal(["total -= 1\nok\n"], mutated("total += 1\nok\n"))
  end

  def test_a_local_variable_target
    assert_equal(["x -= 1"], mutated("x += 1"))
  end

  def test_an_instance_variable_target
    assert_equal(["@total -= 1"], mutated("@total += 1"))
  end

  def test_a_class_variable_target
    assert_equal(["@@total -= 1"], mutated("@@total += 1"))
  end

  def test_a_global_variable_target
    assert_equal(["$total -= 1"], mutated("$total += 1"))
  end

  def test_a_constant_target
    assert_equal(["TOTAL -= 1"], mutated("TOTAL += 1"))
  end

  def test_a_constant_path_target
    assert_equal(["Billing::TOTAL -= 1"], mutated("Billing::TOTAL += 1"))
  end

  def test_an_attribute_target
    assert_equal(["order.total -= 1"], mutated("order.total += 1"))
  end

  def test_a_safe_navigation_attribute_target
    assert_equal(["order&.total -= 1"], mutated("order&.total += 1"))
  end

  def test_an_index_target
    assert_equal(["totals[kind] -= 1"], mutated("totals[kind] += 1"))
  end

  def test_an_or_assignment_to_an_index_target
    assert_equal(["cache[key] &&= []"], mutated("cache[key] ||= []"))
  end

  def test_an_or_assignment_to_each_kind_of_target
    sources = ["x ||= 1", "@x ||= 1", "@@x ||= 1", "$x ||= 1", "X ||= 1", "A::X ||= 1", "a.x ||= 1"]

    assert_equal(sources.map { |source| source.sub("||=", "&&=") }, sources.flat_map { |source| mutated(source) })
  end

  def test_an_and_assignment_becomes_an_or_assignment
    assert_equal(["@total ||= compute"], mutated("@total &&= compute"))
  end

  def test_an_assignment_across_lines
    assert_equal(["x -=\n  1"], mutated("x +=\n  1"))
  end

  def test_an_assignment_inside_an_assignment_makes_a_mutant_for_each_in_the_order_of_the_tree
    assert_equal(["x -= (y += 1)", "x += (y -= 1)"], mutated("x += (y += 1)"))
  end

  def test_the_assignment_of_a_multibyte_name
    assert_equal(["réponse -= 1"], replacements("réponse += 1"))
  end
end
