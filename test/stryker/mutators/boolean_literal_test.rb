# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/mutators/boolean_literal"
require "stryker/mutators/walk"
require_relative("../../support/mutator_case")

# Checks the pairs of BooleanLiteral and the nodes it makes no mutant of, from
# its section of docs/design/mutators.md.
class BooleanLiteralTest < Minitest::Test
  include MutatorCase

  def mutator
    Stryker::Mutators::BooleanLiteral
  end

  def test_is_named_for_the_report
    assert_equal("BooleanLiteral", mutator.name)
  end

  def test_true_becomes_false
    assert_equal(["false"], replacements("true"))
  end

  def test_false_becomes_true
    assert_equal(["true"], replacements("false"))
  end

  def test_the_edit_of_a_literal_covers_the_literal
    edit = edits("ok = true\n").first

    assert_equal([5, 9, "false"], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_not_becomes_its_operand
    assert_equal(["x"], replacements("!x"))
  end

  def test_the_keyword_not_becomes_its_operand
    assert_equal(["x"], replacements("not x"))
  end

  def test_the_keyword_not_with_parentheses_becomes_its_operand
    assert_equal(["x"], replacements("not(x)"))
  end

  def test_not_with_a_space_becomes_its_operand
    assert_equal(["x"], replacements("! x"))
  end

  def test_not_becomes_a_whole_operand
    operands = ["!(a && b)", "!items.empty?", "!réponse"].flat_map { |source| replacements(source) }

    assert_equal(["(a && b)", "items.empty?", "réponse"], operands)
  end

  def test_the_edit_of_a_not_covers_the_whole_call
    edit = edits("ok = !x\n").first

    assert_equal([5, 7, "x"], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_the_mutant_of_a_not_is_the_whole_file_without_the_not
    assert_equal(["ok = x\n"], mutated("ok = !x\n"))
  end

  def test_two_nots_make_an_edit_each_in_the_order_of_the_tree
    assert_equal(["!x", "x"], replacements("!!x"))
  end

  def test_unless_becomes_if_with_an_edit_that_covers_only_the_keyword
    edit = edits("unless c\n  run\nend\n").first

    assert_equal([0, 6, "if"], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_the_mutant_of_an_unless_is_the_whole_file_with_if
    assert_equal(["if c\n  run\nelse\n  stop\nend\n"], mutated("unless c\n  run\nelse\n  stop\nend\n"))
  end

  def test_a_modifier_unless_becomes_if
    assert_equal(["run if c"], mutated("run unless c"))
  end

  def test_until_becomes_while_with_an_edit_that_covers_only_the_keyword
    edit = edits("until done\n  step\nend\n").first

    assert_equal([0, 5, "while"], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_a_modifier_until_becomes_while
    assert_equal(["step while done"], mutated("step until done"))
  end

  def test_a_begin_end_until_becomes_a_begin_end_while
    assert_equal(["begin; step; end while done"], mutated("begin; step; end until done"))
  end

  def test_makes_a_mutant_for_each_site_in_an_expression_in_the_order_of_the_tree
    assert_equal(%w[if x false], replacements("unless !x && true then end"))
  end

  def test_makes_no_mutant_of_nil_or_of_a_keyword_that_is_not_negated
    assert_empty(edits("nil\nif c then x end\nwhile c do x end\nx ? y : z\n"))
  end

  def test_makes_no_mutant_of_not_written_as_a_method_call_or_of_a_comparison
    assert_empty(edits("a.!\na&.!\na != b\na !~ b\n"))
  end

  def test_a_walk_makes_one_mutant_of_two_nots_that_give_the_same_file
    result = Prism.parse("ok = !!ready\n")
    mutants = Stryker::Mutators::Walk.new(file: "a.rb", result:, mutators: [mutator]).mutants

    kept = mutants.map { |mutant| [mutant.id, mutant.start_offset, mutant.end_offset, mutant.replacement] }

    assert_equal([[1, 5, 12, "!ready"]], kept)
  end
end
