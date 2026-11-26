# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/site_case")

# Checks the condition and loop sites from the placement table.
class ConditionSitesTest < Minitest::Test
  include SiteCase

  def test_the_condition_of_an_if
    assert_site("a = 2\nif a > 1\n  p :y\nelse\n  p :n\nend\n", ["a > 1", "a <= 1"], holder: Prism::CallNode)
  end

  def test_the_condition_of_an_unless
    assert_site("a = 2\nunless a > 1\n  p :y\nelse\n  p :n\nend\n", ["a > 1", "a <= 1"], holder: Prism::CallNode)
  end

  def test_the_condition_of_an_elsif
    source = "a = 2\nif a > 5\n  p :big\nelsif a > 1\n  p :middle\nelse\n  p :small\nend\n"

    assert_site(source, ["a > 1", "a > 3"], holder: Prism::CallNode)
  end

  def test_a_whole_elsif
    source = "a = 2\nif a > 5\n  p :big\nelsif a > 1\n  p :middle\nend\n"

    assert_site(source, ["elsif a > 1\n  p :middle\nend", "elsif a > 0\n  p :small\nend"], holder: Prism::IfNode)
  end

  def test_the_condition_of_a_while
    assert_site("i = 0\nwhile i < 3\n  i += 1\nend\np i\n", ["i < 3", "i < 5"], holder: Prism::CallNode)
  end

  def test_the_condition_of_an_until
    assert_site("i = 0\nuntil i >= 3\n  i += 1\nend\np i\n", ["i >= 3", "i >= 5"], holder: Prism::CallNode)
  end

  def test_the_condition_of_a_ternary
    assert_site("a = 2\np(a > 1 ? :y : :n)\n", ["a > 1", "a <= 1"], holder: Prism::CallNode)
  end

  def test_the_condition_of_a_modifier
    assert_site("a = 2\np :y if a > 1\np :done\n", ["a > 1", "a <= 1"], holder: Prism::CallNode)
  end

  def test_a_bare_interpolated_regexp_as_a_condition
    source = "$_ = 'foo'\ns = 'fo'\np :y if /\#{s}o/\np :done\n"

    assert_site(source, ["/\#{s}o/", "/\#{s}x/"], holder: Prism::IfNode)
  end

  def test_a_whole_ternary
    assert_site("a = 2\np(a > 1 ? :y : :n)\n", ["a > 1 ? :y : :n", ":z"], holder: Prism::IfNode)
  end

  def test_the_body_of_a_begin_end_while_loop
    assert_site("i = 0\nbegin\n  i += 1\nend while i > 5\np i\n", ["begin\n  i += 1\nend", "nil"], holder: Prism::WhileNode)
  end

  def test_the_body_of_a_begin_end_until_loop
    source = "i = 0\nbegin\n  i += 1\nend until i < 5\np i\n"

    assert_site(source, ["begin\n  i += 1\nend", "nil"], holder: Prism::UntilNode)
  end

  def test_a_statement_inside_a_begin_end_while_loop
    assert_site("i = 0\nbegin\n  i += 1\nend while i > 5\np i\n", ["i += 1", "i += 2"], holder: Prism::LocalVariableOperatorWriteNode)
  end

  def test_a_when_value
    assert_site("x = 1\ncase x\nwhen 1 then p :one\nelse p :other\nend\n", ["1", "2", 1], holder: Prism::IntegerNode)
  end

  def test_a_case_subject
    assert_site("x = 1\ncase x\nwhen 1 then p :one\nelse p :other\nend\n", ["x", "x + 1", 1], holder: Prism::LocalVariableReadNode)
  end

  def test_the_expression_under_a_when_splat
    assert_site("a = [1]\ncase 1\nwhen *a then p :in\nelse p :out\nend\n", ["a", "[2]", 2], holder: Prism::LocalVariableReadNode)
  end

  def test_a_when_condition_without_a_subject
    assert_site("x = 1\ncase\nwhen x == 1 then p :one\nelse p :other\nend\n", ["x == 1", "x == 2"], holder: Prism::CallNode)
  end

  def test_a_when_body_statement
    assert_site("x = 1\ncase x\nwhen 1 then p :one\nelse p :other\nend\n", ["p :one", "p :uno"], holder: Prism::CallNode)
  end

  def test_a_whole_flip_flop
    source = "r = []\n(1..6).each { |i| r << i if (i == 2)..(i == 4) }\np r\n"

    assert_site(source, ["(i == 2)..(i == 4)", "false"], holder: Prism::IfNode)
  end

  def test_a_flip_flop_endpoint
    source = "r = []\n(1..6).each { |i| r << i if (i == 2)..(i == 4) }\np r\n"

    assert_site(source, ["i == 2", "i == 3"], holder: Prism::CallNode)
  end
end
