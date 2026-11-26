# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/site_case")

# Checks the heredoc and regexp sites from the placement table.
class HeredocAndRegexpSitesTest < Minitest::Test
  include SiteCase

  def test_a_heredoc_opener
    assert_site("s = <<EOS\nhi\nEOS\np s\n", ["<<EOS", "'z'"], holder: Prism::StringNode)
  end

  def test_a_squiggly_heredoc_opener_with_interpolation
    assert_site("x = 1\ns = <<~EOS\n  hi \#{x}\nEOS\np s\n", ["<<~EOS", "'z'"], holder: Prism::InterpolatedStringNode)
  end

  def test_a_raw_heredoc_opener
    assert_site("s = <<~'EOS'\n  a\#{b}\nEOS\np s\n", ["<<~'EOS'", "'z'"], holder: Prism::StringNode)
  end

  def test_a_heredoc_opener_with_a_method_call_after_it
    assert_site("s = <<~EOS.upcase\n  hi\nEOS\np s\n", ["<<~EOS.upcase", "'z'"], holder: Prism::CallNode)
  end

  def test_a_heredoc_opener_as_an_argument_with_more_arguments_after_it
    assert_site("def f(a, b)\n  [a, b]\nend\np f(<<~A, 2)\n  body\nA\n", ["<<~A", "'q'"], holder: Prism::StringNode)
  end

  def test_a_node_whose_range_spans_a_heredocs_body
    source = "def f(a, b)\n  [a, b]\nend\nx = f(<<~A,\n  body\nA\n  2)\np x\n"

    assert_site(source, ["f(<<~A,\n  body\nA\n  2)", "nil"], holder: Prism::CallNode)
  end

  def test_a_node_whose_mutant_keeps_a_heredoc_on_the_line
    source = "def f(s, b: 0, c: 0)\n  [s, b, c]\nend\np f(<<~A, b: 2)\n  body\nA\n"

    assert_site(source, ["b:", "c:", 1], holder: Prism::CallNode)
  end

  def test_a_replacement_that_writes_a_heredoc_opener
    source = "def f(s, n)\n  [s, n]\nend\np f(<<~A, 2)\n  body\nA\n"

    assert_site(source, ["f(<<~A, 2)", "f(<<~A, 3)"], holder: Prism::CallNode)
  end

  def test_a_heredoc_opener_replaced_by_text_on_several_lines
    assert_site("s = <<EOS\n)\nEOS\np s\n", ["<<EOS", "[1,\n  2]"], holder: Prism::StringNode)
  end

  def test_a_node_with_a_heredoc_opener_replaced_by_text_on_several_lines
    source = "def f(s, n)\n  [s, n]\nend\np f(<<~A, 2)\n  )\nA\n"

    assert_site(source, ["f(<<~A, 2)", "[1,\n  2]"], holder: Prism::CallNode)
  end

  def test_an_interpolated_heredoc_opener_replaced_by_text_on_several_lines
    assert_site("x = 1\ns = <<~EOS\n  hi \#{x} )\nEOS\np s\n", ["<<~EOS", "[1,\n  2]"], holder: Prism::InterpolatedStringNode)
  end

  def test_a_command_heredoc_opener_replaced_by_text_on_several_lines
    assert_site("s = <<~`EOS`\n  echo end\nEOS\np s\n", ["<<~`EOS`", "[1,\n  2]"], holder: Prism::XStringNode)
  end

  def test_a_node_that_holds_the_body_of_a_heredoc_whose_opener_is_replaced
    source = "def f(*) = 1\np defined?(f(<<~A,\n  body\nA\n  2))\n"

    assert_site(source, ["<<~A", "g(1,\n  2)"], holder: Prism::DefinedNode)
  end

  def test_the_second_of_two_heredoc_openers_on_a_line
    source = "def f(a, b)\n  [a, b]\nend\np f(<<A, <<B)\none\nA\ntwo\nB\n"

    assert_site(source, ["<<B", "'z'"], holder: Prism::StringNode)
  end

  def test_a_line_of_a_heredocs_body
    assert_site("s = <<~EOS\n  hello\nEOS\np s\n", %w[hello hellx], holder: Prism::StringNode)
  end

  def test_a_line_of_an_interpolated_heredocs_body
    assert_site("x = 1\ns = <<~EOS\n  hello \#{x}\nEOS\np s\n", %w[hello hellx], holder: Prism::InterpolatedStringNode)
  end

  def test_a_line_of_a_heredocs_body_in_a_method
    assert_site("def f\n  <<~EOS\n    hello\n  EOS\nend\np f\n", %w[hello hellx], holder: Prism::StringNode)
  end

  def test_a_line_of_the_body_of_the_second_of_two_heredocs_on_a_line
    source = "def f(a, b)\n  [a, b]\nend\np f(<<A, <<B)\none\nA\ntwo\nB\n"

    assert_site(source, %w[two six], holder: Prism::StringNode)
  end

  def test_an_expression_inside_a_heredocs_interpolation
    assert_site("x = 2\ns = <<~EOS\n  v=\#{x + 1}\nEOS\np s\n", ["x + 1", "x - 1"], holder: Prism::CallNode)
  end

  def test_a_regexp
    assert_site("p 'abc'[/b/]\n", ["/b/", "/c/"], holder: Prism::RegularExpressionNode)
  end

  def test_an_interpolated_regexp
    assert_site("x = 'b'\np 'abc'[/\#{x}/]\n", ["/\#{x}/", "/c/"], holder: Prism::InterpolatedRegularExpressionNode)
  end

  def test_a_regexp_interpolated_once
    assert_site("x = 'b'\np 'abc'[/\#{x}/o]\n", ["/\#{x}/o", "/c/o"], holder: Prism::InterpolatedRegularExpressionNode)
  end

  def test_a_regexp_with_a_capture_read_through_a_global
    assert_site("'abc' =~ /(b)/\np $1\n", ["/(b)/", "/(c)/"], holder: Prism::RegularExpressionNode)
  end

  def test_a_regexp_with_named_captures_on_the_left_of_a_match
    source = "if /(?<x>\\d+)/ =~ 'a12'\n  p x\nend\n"

    assert_site(source, ["/(?<x>\\d+)/", "/(?<x>[a-z]+)/"], holder: Prism::MatchWriteNode)
  end
end
