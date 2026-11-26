# frozen_string_literal: true

require_relative("../../test_helper")
require "prism"
require "stryker/mutators/traversal"

# Checks the nodes a traversal gives, in what order, with which ancestors, and
# the sites it leaves out.
class TraversalTest < Minitest::Test
  # Each node of +source+ as its class and the classes of its ancestors.
  def visits(source)
    traversal = Stryker::Mutators::Traversal.new(Prism.parse(source).value)
    # The ancestors array changes as the traversal goes on, so each one is read
    # as it is yielded.
    nodes = Enumerator.new { |yielder| traversal.each { |node, ancestors| yielder.yield(node, ancestors) } }
    nodes.map { |node, ancestors| [node.class, ancestors.map(&:class)] }
  end

  def classes(source)
    visits(source).map(&:first)
  end

  def test_gives_each_node_before_the_nodes_inside_it
    expected = [
      Prism::ProgramNode,
      Prism::StatementsNode,
      Prism::LocalVariableWriteNode,
      Prism::ArrayNode,
      Prism::IntegerNode,
      Prism::IntegerNode,
    ]

    assert_equal(expected, classes("x = [1, 2]"))
  end

  def test_gives_the_root_no_ancestors
    assert_equal([Prism::ProgramNode, []], visits("1").first)
  end

  def test_gives_each_node_the_nodes_above_it_from_the_root_to_its_parent
    expected = [Prism::IntegerNode, [Prism::ProgramNode, Prism::StatementsNode, Prism::ArrayNode]]

    assert_equal(expected, visits("[1]").last)
  end

  def test_gives_the_ancestors_of_a_node_after_a_sibling_subtree_is_done
    assert_equal([Prism::IntegerNode, [Prism::ProgramNode, Prism::StatementsNode]], visits("[1]\n2").last)
  end

  def test_leaves_out_the_arguments_of_a_call_that_loads_code
    expected = [
      Prism::ProgramNode, Prism::StatementsNode, Prism::CallNode, Prism::LocalVariableWriteNode, Prism::IntegerNode
    ]

    assert_equal(expected, classes("require 'json'\nx = 1"))
  end

  def test_leaves_out_everything_inside_a_type_signature
    assert_equal([Prism::ProgramNode, Prism::StatementsNode, Prism::CallNode], classes("sig { 1 }"))
  end
end
