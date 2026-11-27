# frozen_string_literal: true

require_relative("../../test_helper")
require "prism"
require "stryker/mutators/operand"

# Checks what a mutator that moves an operand needs to know about it.
class OperandTest < Minitest::Test
  def operand(source)
    Prism.parse(source).value.statements.body.first
  end

  def holds_heredoc?(source)
    Stryker::Mutators::Operand.holds_heredoc?(operand(source))
  end

  def test_a_heredoc_opener_is_a_heredoc
    assert(holds_heredoc?("<<~TEXT\n  a\nTEXT\n"))
  end

  def test_an_interpolated_heredoc_opener_is_a_heredoc
    assert(holds_heredoc?("<<~TEXT\n  \#{a}\nTEXT\n"))
  end

  def test_a_backtick_heredoc_opener_is_a_heredoc
    assert(holds_heredoc?("<<~`CMD`\n  ls\nCMD\n"))
  end

  def test_an_interpolated_backtick_heredoc_opener_is_a_heredoc
    assert(holds_heredoc?("<<~`CMD`\n  ls \#{a}\nCMD\n"))
  end

  def test_an_opener_inside_a_call_is_held
    assert(holds_heredoc?("foo(1, bar(<<~TEXT))\n  a\nTEXT\n"))
  end

  def test_an_opener_in_the_receiver_of_a_call_is_held
    assert(holds_heredoc?("<<~TEXT.strip\n  a\nTEXT\n"))
  end

  def test_a_string_with_no_opener_is_no_heredoc
    sources = ["'a'", "\"a\#{b}\"", "`ls`", "`ls \#{b}`", "foo('a', \"b\")", "%q(a)", "?a"]

    assert_equal([false] * 7, sources.map { |source| holds_heredoc?(source) })
  end

  def test_a_node_with_no_string_is_no_heredoc
    assert_equal([false, false], ["a", "foo(1, b)"].map { |source| holds_heredoc?(source) })
  end

  def left_text(source)
    Stryker::Mutators::Operand.left_text(operand(source))
  end

  def test_a_defined_check_with_no_parentheses_goes_in_parentheses_on_the_left
    assert_equal("(defined? b)", left_text("defined? b"))
  end

  def test_a_not_with_no_parentheses_goes_in_parentheses_on_the_left
    assert_equal("(not b)", left_text("not b"))
  end

  def test_an_and_goes_in_parentheses_on_the_left
    assert_equal(["(a and b)", "(a && b)"], ["a and b", "a && b"].map { |source| left_text(source) })
  end

  def test_an_or_goes_in_parentheses_on_the_left
    assert_equal(["(a or b)", "(a || b)"], ["a or b", "a || b"].map { |source| left_text(source) })
  end

  def test_an_assignment_goes_in_parentheses_on_the_left
    sources = ["x = 1", "@x = 1", "@@x = 1", "$x = 1", "X = 1", "B::X = 1", "b.c = 1", "b&.c = 1", "b[0] = 1"]

    assert_equal(sources.map { |source| "(#{source})" }, sources.map { |source| left_text(source) })
  end

  def test_an_assignment_that_changes_its_variable_goes_in_parentheses_on_the_left
    sources = ["x += 1", "x ||= 1", "x &&= 1", "@x ||= 1", "B::X ||= 1", "b.c += 1", "b.c ||= 1", "b[0] += 1"]

    assert_equal(sources.map { |source| "(#{source})" }, sources.map { |source| left_text(source) })
  end

  def test_a_defined_check_with_parentheses_is_its_text_on_the_left
    assert_equal("defined?(b)", left_text("defined?(b)"))
  end

  def test_a_not_with_parentheses_is_its_text_on_the_left
    assert_equal("not(b)", left_text("not(b)"))
  end

  def test_a_bang_is_its_text_on_the_left
    assert_equal("!b", left_text("!b"))
  end

  def test_an_operand_in_parentheses_is_its_text_on_the_left
    sources = ["(a and b)", "(not b)", "(defined? b)"]

    assert_equal(sources, sources.map { |source| left_text(source) })
  end

  def test_other_operands_are_their_text_on_the_left
    sources = ["a", "f(1)", "a + b", "-a", "b.c", "b[0]", "b.c(1)", "b == c"]

    assert_equal(sources, sources.map { |source| left_text(source) })
  end
end
