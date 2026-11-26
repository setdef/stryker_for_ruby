# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/site_case")

# Checks the heredoc and regexp sites from the placement table.
class HeredocAndRegexpSitesTest < Minitest::Test
  include SiteCase

  def test_a_heredoc_opener
    assert_site("s = <<EOS\nhi\nEOS\np s\n", ["<<EOS", "'z'"])
  end

  def test_a_squiggly_heredoc_opener_with_interpolation
    assert_site("x = 1\ns = <<~EOS\n  hi \#{x}\nEOS\np s\n", ["<<~EOS", "'z'"])
  end

  def test_a_raw_heredoc_opener
    assert_site("s = <<~'EOS'\n  a\#{b}\nEOS\np s\n", ["<<~'EOS'", "'z'"])
  end

  def test_a_heredoc_opener_with_a_method_call_after_it
    assert_site("s = <<~EOS.upcase\n  hi\nEOS\np s\n", ["<<~EOS.upcase", "'z'"])
  end

  def test_a_heredoc_opener_as_an_argument_with_more_arguments_after_it
    assert_site("def f(a, b)\n  [a, b]\nend\np f(<<~A, 2)\n  body\nA\n", ["<<~A", "'q'"])
  end

  def test_a_node_whose_range_spans_a_heredocs_body
    source = "def f(a, b)\n  [a, b]\nend\nx = f(<<~A,\n  body\nA\n  2)\np x\n"

    assert_site(source, ["f(<<~A,\n  body\nA\n  2)", "nil"])
  end

  def test_a_node_whose_mutant_keeps_a_heredoc_on_the_line
    source = "def f(s, b: 0, c: 0)\n  [s, b, c]\nend\np f(<<~A, b: 2)\n  body\nA\n"

    assert_site(source, ["b:", "c:", 1])
  end

  def test_a_replacement_that_writes_a_heredoc_opener
    source = "def f(s, n)\n  [s, n]\nend\np f(<<~A, 2)\n  body\nA\n"

    assert_site(source, ["f(<<~A, 2)", "f(<<~A, 3)"])
  end

  def test_an_expression_inside_a_heredocs_interpolation
    assert_site("x = 2\ns = <<~EOS\n  v=\#{x + 1}\nEOS\np s\n", ["x + 1", "x - 1"])
  end

  def test_a_regexp
    assert_site("p 'abc'[/b/]\n", ["/b/", "/c/"])
  end

  def test_an_interpolated_regexp
    assert_site("x = 'b'\np 'abc'[/\#{x}/]\n", ["/\#{x}/", "/c/"])
  end

  def test_a_regexp_interpolated_once
    assert_site("x = 'b'\np 'abc'[/\#{x}/o]\n", ["/\#{x}/o", "/c/o"])
  end

  def test_a_regexp_with_a_capture_read_through_a_global
    assert_site("'abc' =~ /(b)/\np $1\n", ["/(b)/", "/(c)/"])
  end

  def test_a_regexp_with_named_captures_on_the_left_of_a_match
    source = "if /(?<x>\\d+)/ =~ 'a12'\n  p x\nend\n"

    assert_site(source, ["/(?<x>\\d+)/", "/(?<x>[a-z]+)/"])
  end
end
