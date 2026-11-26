# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/site_case")

# Checks the whole unless, case, and begin sites from the conditions and
# loops table of the placement design.
class UnlessCaseAndBeginSitesTest < Minitest::Test
  include SiteCase

  def test_a_whole_unless
    assert_site("a = 2\nunless a > 1\n  p :y\nelse\n  p :n\nend\n", %w[unless if], holder: Prism::UnlessNode)
  end

  def test_a_modifier_unless
    assert_site("a = 2\np :y unless a > 5\n", ["p :y unless a > 5", "p :n unless a > 5"], holder: Prism::UnlessNode)
  end

  def test_a_whole_case
    source = "x = 2\ncase x\nwhen 1 then p :one\nelse p :other\nend\n"

    assert_site(source, ["else p :other", "else p :another"], holder: Prism::CaseNode)
  end

  def test_a_whole_begin
    assert_site("x = begin\n  1\nend\np x\n", ["begin\n  1\nend", "2"], holder: Prism::BeginNode)
  end

  def test_the_rescue_clause_of_a_begin
    source = "begin\n  raise 'a'\nrescue\n  p :rescued\nend\n"

    assert_site(source, ["rescue\n  p :rescued", "rescue\n  p :saved"], holder: Prism::BeginNode)
  end

  def test_a_begin_as_the_body_of_a_while
    source = "i = 0\nwhile i < 3\n  begin\n    i += 1\n  end\nend\np i\n"

    assert_site(source, ["begin\n    i += 1\n  end", "begin\n    i += 2\n  end"], holder: Prism::BeginNode)
  end

  def test_the_rescue_clause_of_a_method_body
    source = "def f\n  raise 'a'\nrescue\n  :rescued\nend\np f\n"

    assert_site(source, ["rescue\n  :rescued", "rescue\n  :saved"], holder: Prism::DefNode)
  end

  def test_the_rescue_clause_of_a_block
    source = "[1].each do |x|\n  raise 'a'\nrescue\n  p :rescued\nend\n"

    assert_site(source, ["rescue\n  p :rescued", "rescue\n  p :saved"], holder: Prism::CallNode)
  end
end
