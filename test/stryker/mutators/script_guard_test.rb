# frozen_string_literal: true

require_relative("../../test_helper")
require "prism"
require "stryker/mutators/script_guard"
require_relative("../../support/mutator_case")

# Checks which nodes are the check that a file is the script that runs, and
# which nodes that check decides.
class ScriptGuardTest < Minitest::Test
  include MutatorCase

  def tree(source)
    Prism.parse(source).value.statements
  end

  def check?(source)
    Stryker::Mutators::ScriptGuard.check?(tree(source).body.first)
  end

  def checks(sources)
    sources.map { |source| check?(source) }
  end

  def decided(source)
    nodes_of(tree(source)).filter_map { |node, _| node.class if Stryker::Mutators::ScriptGuard.decided_by?(node) }
  end

  def test_the_file_compared_with_the_script_name_is_the_check_either_way_round
    sources = ["__FILE__ == $0", "$0 == __FILE__", "__FILE__ == $PROGRAM_NAME", "$PROGRAM_NAME == __FILE__"]

    assert_equal([true] * 4, checks(sources))
  end

  def test_the_check_in_parentheses_is_the_check
    assert_equal([true] * 3, checks(["(__FILE__ == $0)", "((__FILE__ == $0))", "( $0 == __FILE__ )"]))
  end

  def test_a_comparison_of_something_else_is_no_check
    others = ["__FILE__ == name", "$0 != __FILE__", "$0 == $PROGRAM_NAME", "(__FILE__ != $0)", "a", "()"]

    assert_equal([false] * 6, checks(others))
  end

  def test_parentheses_around_more_than_one_statement_are_no_check
    refute(check?("(a; __FILE__ == $0)"))
  end

  def test_the_condition_of_an_if_is_decided_by_the_check
    assert_equal([Prism::IfNode], decided("if __FILE__ == $0\n  run\nend\n"))
  end

  def test_the_condition_of_a_modifier_if_is_decided_by_the_check
    assert_equal([Prism::IfNode], decided("run if __FILE__ == $0"))
  end

  def test_the_condition_of_an_elsif_is_decided_by_the_check
    assert_equal([Prism::IfNode], decided("if a\n  x\nelsif __FILE__ == $0\n  y\nend\n"))
  end

  def test_the_condition_of_a_ternary_is_decided_by_the_check
    assert_equal([Prism::IfNode], decided("__FILE__ == $0 ? a : b"))
  end

  def test_the_condition_of_an_unless_is_decided_by_the_check
    assert_equal([Prism::UnlessNode] * 2, decided("unless __FILE__ == $0\n  a\nend\nb unless $0 == __FILE__"))
  end

  def test_the_condition_of_a_while_and_of_an_until_is_decided_by_the_check
    assert_equal([Prism::WhileNode, Prism::UntilNode], decided("a while __FILE__ == $0\nb until __FILE__ == $0"))
  end

  def test_a_condition_in_parentheses_is_decided_by_the_check
    assert_equal([Prism::IfNode], decided("if (__FILE__ == $0)\n  run\nend\n"))
  end

  def test_either_operand_of_a_logical_operator_is_decided_by_the_check
    sources = ["__FILE__ == $0 && a", "a || __FILE__ == $0", "__FILE__ == $0 and a", "a or (__FILE__ == $0)"]

    assert_equal([[Prism::AndNode], [Prism::OrNode], [Prism::AndNode], [Prism::OrNode]], sources.map { |s| decided(s) })
  end

  def test_the_operand_of_a_negation_is_decided_by_the_check
    sources = ["!(__FILE__ == $0)", "not(__FILE__ == $0)", "!($0 == __FILE__)"]

    assert_equal([[Prism::CallNode]] * 3, sources.map { |source| decided(source) })
  end

  def test_a_node_with_the_check_deeper_inside_it_is_not_decided_by_it
    # Only the innermost &&, which has the check as an operand, is decided.
    assert_equal([Prism::AndNode], decided("a && (b || (c && __FILE__ == $0))"))
  end

  def test_the_check_itself_is_decided_by_nothing
    assert_empty(decided("__FILE__ == $0"))
  end

  def test_a_node_whose_condition_is_something_else_is_decided_by_nothing
    sources = ["if __FILE__ == name\n  a\nend\n", "a && b", "!a", "if a && __FILE__ == $0 then b end"]

    assert_equal([[], [], [], [Prism::AndNode]], sources.map { |source| decided(source) })
  end

  def test_the_body_of_a_condition_is_not_decided_by_the_check
    assert_equal([Prism::IfNode], decided("if __FILE__ == $0\n  x = (a && b)\n  y = !c\nend\n"))
  end
end
