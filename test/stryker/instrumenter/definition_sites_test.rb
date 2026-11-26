# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/site_case")

# Checks the definition sites from the statements and definitions table of the
# placement design: aliases, undef, methods, and constants.
class DefinitionSitesTest < Minitest::Test
  include SiteCase

  def test_an_alias
    assert_site("def f\n  1\nend\nalias g f\np respond_to?(:g, true)\n", ["alias g f", "nil"], holder: Prism::AliasMethodNode)
  end

  def test_an_alias_of_a_global
    assert_site("$x = 1\nalias $y $x\np $y\n", ["alias $y $x", "nil"], holder: Prism::AliasGlobalVariableNode)
  end

  def test_an_undef
    assert_site("def f\n  1\nend\nundef f\np respond_to?(:f, true)\n", ["undef f", "nil"], holder: Prism::UndefNode)
  end

  def test_a_name_in_an_alias
    assert_site("def x = 1\ndef y = 2\nalias z x\np z\n", ["x", "y", 1], holder: Prism::AliasMethodNode)
  end

  def test_a_name_in_an_undef
    assert_site("def a = 1\ndef b = 2\nundef a\np respond_to?(:a, true)\n", ["a", "b", 1], holder: Prism::UndefNode)
  end

  def test_a_method_name_in_a_def
    assert_site("def foo\n  1\nend\np respond_to?(:foo, true)\n", %w[foo bar], holder: Prism::DefNode)
  end

  def test_a_whole_endless_def
    assert_site("def foo = 1\np respond_to?(:foo, true)\n", ["def foo = 1", "def bar = 1"], holder: Prism::DefNode)
  end

  def test_an_endless_method_body
    assert_site("def f(x) = x + 1\np f(1)\n", ["x + 1", "x - 1"], holder: Prism::CallNode)
  end

  def test_an_endless_method_body_that_is_a_command
    assert_site("def f(x) = puts x\nf(1)\n", ["puts x", "puts x + 1"], holder: Prism::CallNode)
  end

  def test_the_def_given_to_private
    source = "class A\n  private def foo = 1\n  def bar = foo\nend\np A.new.bar\n"

    assert_site(source, ["def foo = 1", "def foo = 3"], holder: Prism::DefNode)
  end

  def test_the_body_of_a_def_given_to_private
    assert_site("class A\n  private def foo = 1\n  def bar = foo\nend\np A.new.bar\n", %w[1 2], holder: Prism::IntegerNode)
  end

  def test_a_whole_call_to_private_with_a_def
    source = "class A\n  private def foo = 1\nend\np A.private_instance_methods(false)\n"

    assert_site(source, ["private def foo = 1", "nil"], holder: Prism::CallNode)
  end

  def test_a_bare_private
    assert_site("class A\n  private\n  def foo = 1\nend\np A.new.respond_to?(:foo)\n", %w[private nil], holder: Prism::CallNode)
  end

  def test_a_def_after_a_bare_private
    source = "class A\n  private\n  def foo = 1\nend\np A.new.send(:foo)\n"

    assert_site(source, ["def foo = 1", "def foo = 2"], holder: Prism::DefNode)
  end

  def test_a_constants_value_in_a_file
    assert_site("X = 1\np X\n", %w[1 2], holder: Prism::IntegerNode)
  end

  def test_a_constants_value_in_a_class_body
    assert_site("class A\n  X = 1\nend\np A::X\n", %w[1 2], holder: Prism::IntegerNode)
  end

  def test_a_constants_value_with_or_assign
    assert_site("X ||= 1\np X\n", %w[1 2], holder: Prism::IntegerNode)
  end

  def test_a_whole_constant_assignment
    assert_site("X = 1\np defined?(X)\n", ["X = 1", "nil"], holder: Prism::ConstantWriteNode)
  end

  def test_a_call_in_a_class_body
    assert_site("class A\n  attr_reader :a\nend\np A.instance_methods(false)\n", ["attr_reader :a", "nil"], holder: Prism::CallNode)
  end
end
