# frozen_string_literal: true

require_relative("../../test_helper")
require "prism"
require "stryker/mutators/operation"

# Checks which calls are operations, what edits an operation makes from a table
# of pairs, and the calls it refuses.
class OperationTest < Minitest::Test
  PAIRS = { "+": %w[- *], "-": %w[+] }.freeze
  private_constant(:PAIRS)

  def call(source)
    Prism.parse(source).value.statements.body.first
  end

  def operation(source, names = %i[+ -])
    Stryker::Mutators::Operation.of(call(source), names)
  end

  def replacements(source, &)
    Stryker::Mutators::Operation.edits(call(source), PAIRS, &).map(&:replacement)
  end

  def test_a_call_written_as_an_operator_is_an_operation_with_its_parts
    operation = operation("a + 1")
    parts = [operation.operator, operation.receiver.slice, operation.argument.slice, operation.operator_loc.slice]

    assert_equal([:+, "a", "1", "+"], parts)
  end

  def test_a_node_that_is_not_a_call_is_no_operation
    assert_nil(operation("a = 1"))
  end

  def test_a_call_with_another_name_is_no_operation
    assert_nil(operation("a * 1"))
  end

  def test_a_call_written_with_a_dot_is_no_operation
    assert_equal([nil, nil, nil], ["a.+(1)", "a&.+(1)", "self.+(1)"].map { |source| operation(source) })
  end

  def test_a_call_built_by_hand_without_a_receiver_is_no_operation
    assert_nil(Stryker::Mutators::Operation.of(call("a + 1").copy(receiver: nil), [:+]))
  end

  def test_a_call_built_by_hand_without_arguments_is_no_operation
    assert_nil(Stryker::Mutators::Operation.of(call("a + 1").copy(arguments: nil), [:+]))
  end

  def test_a_call_built_by_hand_with_an_empty_argument_list_is_no_operation
    plus = call("a + 1")

    assert_nil(Stryker::Mutators::Operation.of(plus.copy(arguments: plus.arguments.copy(arguments: [])), [:+]))
  end

  def test_a_call_built_by_hand_without_an_operator_location_is_no_operation
    assert_nil(Stryker::Mutators::Operation.of(call("a + 1").copy(message_loc: nil), [:+]))
  end

  def test_an_operation_with_a_string_operand_says_so
    strings = ["a + 'b'", "'a' + b", "a + b"].map { |source| operation(source).string_operand? }

    assert_equal([true, true, false], strings)
  end

  def test_makes_an_edit_for_each_replacement_of_the_table_in_its_order
    assert_equal(["a - b", "a * b"], replacements("a + b") { false })
  end

  def test_makes_an_edit_that_covers_the_whole_call_and_keeps_the_text_around_the_operator
    edits = Stryker::Mutators::Operation.edits(call("total = a  +\n  b").value, PAIRS) { false }
    edit = edits.first

    assert_equal([8, 16, "a  -\n  b"], [edit.start_offset, edit.end_offset, edit.replacement])
  end

  def test_makes_no_edit_when_the_block_is_true_of_the_operation
    assert_empty(replacements("a + b") { |operation| operation.operator == :+ })
  end

  def test_asks_the_block_about_the_operation
    asked = []
    replacements("a - 1") { |operation| asked << operation.argument.slice }

    assert_equal(["1"], asked)
  end

  def test_makes_no_edit_of_a_call_that_is_not_an_operation_and_never_asks_the_block
    assert_empty(replacements("a.+(b)") { raise(ArgumentError, "The block ran.") })
  end

  def test_makes_no_edit_of_an_operator_the_table_does_not_list
    assert_empty(Stryker::Mutators::Operation.edits(call("a - b"), { "+": %w[-] }) { false })
  end
end
