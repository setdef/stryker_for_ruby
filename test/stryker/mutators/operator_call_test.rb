# frozen_string_literal: true

require_relative("../../test_helper")
require "prism"
require "stryker/mutators/operator_call"

# Checks which nodes are calls written as operators.
class OperatorCallTest < Minitest::Test
  def operator_call(source, names)
    node = Prism.parse(source).value.statements.body.first
    Stryker::Mutators::OperatorCall.of(node, names)
  end

  def test_a_call_named_by_the_list_and_written_with_no_dot_is_an_operator_call
    assert_equal("a + b", operator_call("a + b", [:+]).slice)
  end

  def test_a_prefix_operator_is_an_operator_call
    assert_equal("!a", operator_call("!a", [:!]).slice)
  end

  def test_a_call_with_another_name_is_none
    assert_nil(operator_call("a - b", [:+]))
  end

  def test_a_call_written_with_a_dot_is_none
    assert_equal([nil, nil, nil], ["a.+(b)", "a&.+(b)", "self.+(b)"].map { |source| operator_call(source, [:+]) })
  end

  def test_a_node_that_is_not_a_call_is_none
    assert_nil(operator_call("a = 1", [:+]))
  end
end
