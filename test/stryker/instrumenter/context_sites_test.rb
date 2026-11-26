# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/site_case")

# Checks mutants whose text spans several lines and holds code that parses
# only where it stands in the file: yield in a method, break and next in a
# block, and retry in a rescue. Each mutant's text goes on one line, which
# parses in the plain mutant, in place of the node. So does the text of a
# replacement that makes several statements where a body held one.
class ContextSitesTest < Minitest::Test
  include SiteCase

  def test_a_yield
    source = "def g\n  if true\n    yield 1\n  end\nend\ng { |x| p x }\n"

    assert_site(source, ["if true\n    yield 1\n  end", "if true\n    yield 2\n  end"], holder: Prism::IfNode)
  end

  def test_a_break
    source = "r = [1, 2].each do |x|\n  if x > 0\n    break x * 10\n  end\nend\np r\n"

    assert_site(source, ["if x > 0\n    break x * 10\n  end", "if x > 0\n    break x * 20\n  end"], holder: Prism::IfNode)
  end

  def test_a_next
    source = "r = [1, 2].map do |x|\n  if x > 1\n    next 0\n  end\n  x\nend\np r\n"

    assert_site(source, ["if x > 1\n    next 0\n  end", "if x > 1\n    next 5\n  end"], holder: Prism::IfNode)
  end

  def test_a_retry
    source = "n = 0\nbegin\n  n += 1\n  raise 'a' if n < 3\nrescue\n  if n < 3\n    retry\n  end\nend\np n\n"

    assert_site(source, ["if n < 3\n    retry\n  end", "if n < 2\n    retry\n  end"], holder: Prism::IfNode)
  end

  def test_a_replacement_that_makes_several_statements_where_a_body_held_one
    source = "def f(c)\n  if c\n    1\n  end\nend\np f(true)\n"

    assert_site(source, ["if c", "if c then p 5 end; if !c"], holder: Prism::IfNode)
  end

  def test_a_node_that_keeps_a_heredoc_whose_body_is_not_code
    source = "def f(s, b: 0, c: 0)\n  [s, b, c]\nend\np f(<<~A, b: 2)\n  ) not code\nA\n"

    assert_site(source, ["b:", "c:", 1], holder: Prism::CallNode)
  end
end
