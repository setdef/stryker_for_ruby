# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/site_case")

# Checks the statement and definition sites from the placement table.
class StatementSitesTest < Minitest::Test
  include SiteCase

  def test_a_statement_removed_in_a_method
    assert_site("def f\n  puts 'a'\n  puts 'b'\nend\nf\n", ["puts 'a'", "nil"], holder: Prism::CallNode)
  end

  def test_the_last_statement_removed_in_a_method
    assert_site("def f\n  puts 'a'\n  2\nend\np f\n", %w[2 nil], holder: Prism::IntegerNode)
  end

  def test_a_statement_removed_in_a_block
    assert_site("[1].each do |x|\n  puts 'a'\n  puts x\nend\n", ["puts x", "nil"], holder: Prism::CallNode)
  end

  def test_a_return
    assert_site("def f\n  return 1\nend\np f\n", ["return 1", "return 2"], holder: Prism::ReturnNode)
  end

  def test_a_return_as_an_operand
    assert_site("def f(a)\n  a or return 2\n  a\nend\np f(nil)\n", ["return 2", "return 3"], holder: Prism::ReturnNode)
  end

  def test_a_next
    assert_site("p([1, 2].map { |x| next x * 2 })\n", ["next x * 2", "next x"], holder: Prism::NextNode)
  end

  def test_a_break
    assert_site("p([1, 2].each { |x| break x })\n", ["break x", "break 5"], holder: Prism::BreakNode)
  end

  def test_a_redo
    assert_site("n = 0\n[1].each do\n  n += 1\n  redo if n < 3\nend\np n\n", %w[redo nil], holder: Prism::RedoNode)
  end

  def test_a_retry
    source = "n = 0\nbegin\n  n += 1\n  raise 'again' if n < 3\nrescue\n  retry\nend\np n\n"

    assert_site(source, %w[retry nil], holder: Prism::RetryNode)
  end

  def test_a_returned_value
    assert_site("def f\n  return 1\nend\np f\n", %w[1 2], holder: Prism::IntegerNode)
  end

  def test_an_expression_inside_defined
    assert_site("foo = 1\np foo\np defined?(foo)\n", ["foo", "bar", 2], holder: Prism::DefinedNode)
  end

  def test_a_whole_defined
    assert_site("foo = 1\np defined?(foo)\n", ["defined?(foo)", "nil"], holder: Prism::DefinedNode)
  end

  def test_a_whole_defined_of_yield
    assert_site("def g\n  defined?(yield)\nend\np g\np(g {})\n", ["defined?(yield)", "nil"], holder: Prism::DefinedNode)
  end

  def test_an_end_block
    assert_site("END { p :end }\np :main\n", ["END { p :end }", "nil"], holder: Prism::PostExecutionNode)
  end
end
