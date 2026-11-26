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
end
