# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/site_case")

# Checks the call sites from the placement table.
class CallSitesTest < Minitest::Test
  include SiteCase

  def test_an_argument
    assert_site("def f(x)\n  x * 2\nend\np f(3)\n", %w[3 4], holder: Prism::IntegerNode)
  end

  def test_a_call_removed_as_a_value
    assert_site("def f\n  1\nend\nx = f\np x\n", ["f", "nil", 2], holder: Prism::CallNode)
  end

  def test_a_call_removed_as_a_statement
    assert_site("def f\n  puts 'f'\nend\nf\np :done\n", ["f", "nil", 3], holder: Prism::CallNode)
  end

  def test_a_call_replaced_by_its_receiver
    assert_site("s = 'ab'\np s.upcase\n", ["s.upcase", "s"], holder: Prism::CallNode)
  end

  def test_a_call_with_a_brace_block
    assert_site("p([1, 2].map { |x| x * 2 })\n", ["[1, 2].map { |x| x * 2 }", "[]"], holder: Prism::CallNode)
  end

  def test_a_call_with_a_do_end_block
    source = "r = [1, 2].map do |x|\n  x * 2\nend\np r\n"

    assert_site(source, ["[1, 2].map do |x|\n  x * 2\nend", "[]"], holder: Prism::CallNode)
  end

  def test_a_command_calls_argument_before_do
    source = "def show(x)\n  p x\n  yield\nend\nshow [1, 2].sum do\n  p :block\nend\n"

    assert_site(source, ["[1, 2].sum", "[]"], holder: Prism::CallNode)
  end

  def test_a_safe_navigation_read
    assert_site("a = 'xy'\np a&.length\n", ["a&.length", "a&.length&.succ"], holder: Prism::CallNode)
  end

  def test_a_safe_navigation_chain
    assert_site("a = 'xy'\np a&.upcase&.length\n", ["a&.upcase&.length", "a&.upcase"], holder: Prism::CallNode)
  end

  def test_a_safe_navigation_assignment
    assert_site("S = Struct.new(:x)\na = S.new(0)\na&.x = 1\np a.x\n", ["a&.x = 1", "a&.x = 2"], holder: Prism::CallNode)
  end

  def test_a_safe_navigation_operator_assignment
    assert_site("S = Struct.new(:x)\na = S.new(0)\na&.x += 1\np a.x\n", ["a&.x += 1", "a&.x -= 1"], holder: Prism::CallOperatorWriteNode)
  end

  def test_the_right_side_of_a_safe_navigation_assignment
    assert_site("S = Struct.new(:x)\na = S.new(0)\na&.x = 1\np a.x\n", %w[1 2], holder: Prism::IntegerNode)
  end

  def test_an_index_call
    assert_site("a = [1, 2]\np a[0]\n", ["a[0]", "a[1]"], holder: Prism::CallNode)
  end

  def test_an_attribute_assignment
    assert_site("S = Struct.new(:x)\na = S.new(0)\na.x = 1\np a.x\n", ["a.x = 1", "a.x = 2"], holder: Prism::CallNode)
  end

  def test_a_lambda_literal
    assert_site("f = ->(x) { x }\np f.(1)\n", ["->(x) { x }", "->(x) { 0 }"], holder: Prism::LambdaNode)
  end

  def test_a_yield_with_arguments
    assert_site("def g\n  yield(1)\nend\ng { |x| p x }\n", ["yield(1)", "yield(2)"], holder: Prism::YieldNode)
  end

  def test_a_yield_removed
    assert_site("def g\n  yield\n  :done\nend\np(g { p :in })\n", %w[yield nil], holder: Prism::YieldNode)
  end

  def test_a_super_with_arguments
    source = "class A\n  def f(a)\n    a\n  end\nend\nclass B < A\n  def f(a)\n    super(a)\n  end\nend\np B.new.f(1)\n"

    assert_site(source, ["super(a)", "super(a + 1)"], holder: Prism::SuperNode)
  end

  def test_a_bare_super
    source = "class A\n  def f(a)\n    a\n  end\nend\nclass B < A\n  def f(a)\n    super\n  end\nend\np B.new.f(1)\n"

    assert_site(source, %w[super 0], holder: Prism::ForwardingSuperNode)
  end

  def test_the_method_name_through_an_alias
    assert_site("def f\n  __method__\nend\nalias g f\np g\n", ["__method__", ":z"], holder: Prism::CallNode)
  end

  def test_the_line_number
    assert_site("x = 1\np x\np __LINE__\n", %w[__LINE__ 0], holder: Prism::SourceLineNode)
  end

  def test_the_file_name
    assert_site("p __FILE__\n", ["__FILE__", "'x'"], holder: Prism::SourceFileNode)
  end

  def test_the_directory_name
    assert_site("p __dir__ == Dir.pwd\n", ["__dir__", "'x'"], holder: Prism::CallNode)
  end
end
