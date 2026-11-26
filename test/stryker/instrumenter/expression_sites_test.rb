# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/site_case")

# Checks the constant, variable, self, nil, true, false, and parentheses sites
# from the reads and keywords table of the placement design.
class ExpressionSitesTest < Minitest::Test
  include SiteCase

  def test_a_constant
    assert_site("X = 1\nY = 2\np X\n", ["X", "Y", 1], holder: Prism::ConstantReadNode)
  end

  def test_a_constant_path
    assert_site("module A\n  X = 1\n  Y = 2\nend\np A::X\n", ["A::X", "A::Y"], holder: Prism::ConstantPathNode)
  end

  def test_the_parent_of_a_constant_path
    source = "module A\n  X = 1\nend\nmodule B\n  X = 2\nend\np A::X\n"

    assert_site(source, ["A", "B", 1], holder: Prism::ConstantReadNode)
  end

  def test_a_superclass
    assert_site("class A < String\nend\np A.superclass\n", %w[String Array], holder: Prism::ConstantReadNode)
  end

  def test_a_class_name
    source = "if true\n  class Foo\n  end\nend\np defined?(Foo)\n"

    assert_site(source, %w[Foo Bar], holder: Prism::IfNode)
  end

  def test_an_instance_variable
    assert_site("@x = 1\n@y = 2\np @x\n", ["@x", "@y", 1], holder: Prism::InstanceVariableReadNode)
  end

  def test_a_class_variable
    source = "class A\n  @@x = 1\n  def self.f\n    @@x\n  end\nend\np A.f\n"

    assert_site(source, ["@@x", "2", 1], holder: Prism::ClassVariableReadNode)
  end

  def test_a_global_variable
    assert_site("$x = 1\np $x\n", ["$x", "2", 1], holder: Prism::GlobalVariableReadNode)
  end

  def test_a_name_in_an_alias_of_a_global
    assert_site("$x = 1\n$z = 2\nalias $y $x\np $y\n", ["$x", "$z", 1], holder: Prism::AliasGlobalVariableNode)
  end

  def test_self
    assert_site("p self\n", %w[self 1], holder: Prism::SelfNode)
  end

  def test_nil
    assert_site("x = nil\np x\n", %w[nil 1], holder: Prism::NilNode)
  end

  def test_true
    assert_site("p true\n", %w[true false], holder: Prism::TrueNode)
  end

  def test_false
    assert_site("p false\n", %w[false true], holder: Prism::FalseNode)
  end

  def test_parentheses
    assert_site("p((1 + 2) * 3)\n", ["(1 + 2)", "(1 - 2)"], holder: Prism::ParenthesesNode)
  end
end
