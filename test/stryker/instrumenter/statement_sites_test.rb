# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/site_case")

# Checks the statement and definition sites from the placement table.
class StatementSitesTest < Minitest::Test
  include SiteCase

  def test_a_statement_removed_in_a_method
    assert_site("def f\n  puts 'a'\n  puts 'b'\nend\nf\n", ["puts 'a'", "nil"])
  end

  def test_the_last_statement_removed_in_a_method
    assert_site("def f\n  puts 'a'\n  2\nend\np f\n", %w[2 nil])
  end

  def test_a_statement_removed_in_a_block
    assert_site("[1].each do |x|\n  puts 'a'\n  puts x\nend\n", ["puts x", "nil"])
  end

  def test_a_return
    assert_site("def f\n  return 1\nend\np f\n", ["return 1", "return 2"])
  end

  def test_a_return_as_an_operand
    assert_site("def f(a)\n  a or return 2\n  a\nend\np f(nil)\n", ["return 2", "return 3"])
  end

  def test_a_next
    assert_site("p([1, 2].map { |x| next x * 2 })\n", ["next x * 2", "next x"])
  end

  def test_a_break
    assert_site("p([1, 2].each { |x| break x })\n", ["break x", "break 5"])
  end

  def test_a_redo
    assert_site("n = 0\n[1].each do\n  n += 1\n  redo if n < 3\nend\np n\n", %w[redo nil])
  end

  def test_a_retry
    source = "n = 0\nbegin\n  n += 1\n  raise 'again' if n < 3\nrescue\n  retry\nend\np n\n"

    assert_site(source, %w[retry nil])
  end

  def test_a_returned_value
    assert_site("def f\n  return 1\nend\np f\n", %w[1 2])
  end

  def test_an_expression_inside_defined
    assert_site("foo = 1\np foo\np defined?(foo)\n", ["foo", "bar", 2])
  end

  def test_a_whole_defined
    assert_site("foo = 1\np defined?(foo)\n", ["defined?(foo)", "nil"])
  end

  def test_a_whole_defined_of_yield
    assert_site("def g\n  defined?(yield)\nend\np g\np(g {})\n", ["defined?(yield)", "nil"])
  end

  def test_an_end_block
    assert_site("END { p :end }\np :main\n", ["END { p :end }", "nil"])
  end

  def test_an_alias
    assert_site("def f\n  1\nend\nalias g f\np respond_to?(:g, true)\n", ["alias g f", "nil"])
  end

  def test_an_alias_of_a_global
    assert_site("$x = 1\nalias $y $x\np $y\n", ["alias $y $x", "nil"])
  end

  def test_an_undef
    assert_site("def f\n  1\nend\nundef f\np respond_to?(:f, true)\n", ["undef f", "nil"])
  end

  def test_a_method_name_in_a_def
    assert_site("def foo\n  1\nend\np respond_to?(:foo, true)\n", %w[foo bar])
  end

  def test_a_whole_endless_def
    assert_site("def foo = 1\np respond_to?(:foo, true)\n", ["def foo = 1", "def bar = 1"])
  end

  def test_an_endless_method_body
    assert_site("def f(x) = x + 1\np f(1)\n", ["x + 1", "x - 1"])
  end

  def test_an_endless_method_body_that_is_a_command
    assert_site("def f(x) = puts x\nf(1)\n", ["puts x", "puts x + 1"])
  end

  def test_the_def_given_to_private
    source = "class A\n  private def foo = 1\n  def bar = foo\nend\np A.new.bar\n"

    assert_site(source, ["def foo = 1", "def foo = 3"])
  end

  def test_the_body_of_a_def_given_to_private
    assert_site("class A\n  private def foo = 1\n  def bar = foo\nend\np A.new.bar\n", %w[1 2])
  end

  def test_a_whole_call_to_private_with_a_def
    source = "class A\n  private def foo = 1\nend\np A.private_instance_methods(false)\n"

    assert_site(source, ["private def foo = 1", "nil"])
  end

  def test_a_bare_private
    assert_site("class A\n  private\n  def foo = 1\nend\np A.new.respond_to?(:foo)\n", %w[private nil])
  end

  def test_a_def_after_a_bare_private
    assert_site("class A\n  private\n  def foo = 1\nend\np A.new.send(:foo)\n", ["def foo = 1", "def foo = 2"])
  end

  def test_a_constants_value_in_a_file
    assert_site("X = 1\np X\n", %w[1 2])
  end

  def test_a_constants_value_in_a_class_body
    assert_site("class A\n  X = 1\nend\np A::X\n", %w[1 2])
  end

  def test_a_constants_value_with_or_assign
    assert_site("X ||= 1\np X\n", %w[1 2])
  end

  def test_a_whole_constant_assignment
    assert_site("X = 1\np defined?(X)\n", ["X = 1", "nil"])
  end

  def test_a_call_in_a_class_body
    assert_site("class A\n  attr_reader :a\nend\np A.instance_methods(false)\n", ["attr_reader :a", "nil"])
  end
end
