# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/site_case")

# Checks the pattern-matching sites from the conditions and loops table of the
# placement design: case/in, x in pattern, and x => pattern.
class PatternSitesTest < Minitest::Test
  include SiteCase

  def test_a_case_in_pattern
    assert_site("case 5\nin Integer then p :int\nelse p :other\nend\n", %w[Integer String], holder: Prism::CaseMatchNode)
  end

  def test_a_whole_case_in
    source = "case 5\nin Integer then p :int\nelse p :other\nend\n"

    assert_site(source, [source.chomp, "case 5\nin String then p :str\nelse p :other\nend"], holder: Prism::CaseMatchNode)
  end

  def test_a_part_of_a_case_in_pattern
    assert_site("case [1, 'a']\nin [Integer, String] then p :yes\nelse p :no\nend\n", %w[String Symbol], holder: Prism::CaseMatchNode)
  end

  def test_a_case_in_pinned_expression
    assert_site("case 5\nin ^(2 + 3) then p :five\nelse p :other\nend\n", ["2 + 3", "9"], holder: Prism::CallNode)
  end

  def test_a_case_in_guard
    assert_site("case 5\nin Integer => y if y > 1\n  p y\nelse p :other\nend\n", ["y > 1", "y > 9"], holder: Prism::CallNode)
  end

  def test_a_case_in_unless_guard
    source = "case 5\nin Integer => y unless y > 9\n  p y\nelse p :other\nend\n"

    assert_site(source, ["y > 9", "y > 1"], holder: Prism::CallNode)
  end

  def test_a_value_in_a_case_in_pattern
    assert_site("case 5\nin 5 then p :five\nelse p :other\nend\n", ["5", "6", 1], holder: Prism::CaseMatchNode)
  end

  def test_a_value_in_a_case_in_pattern_with_a_guard
    source = "case 5\nin 5 => y if y > 1\n  p y\nelse p :other\nend\n"

    assert_site(source, ["5", "6", 1], holder: Prism::CaseMatchNode)
  end

  def test_a_case_in_body_statement
    assert_site("case 5\nin Integer => y\n  p y\nend\n", ["p y", "p y + 1"], holder: Prism::CallNode)
  end

  def test_a_match_predicate
    assert_site("p((5 in Integer))\n", ["5 in Integer", "5 in String"], holder: Prism::MatchPredicateNode)
  end

  def test_a_pattern_inside_a_match_predicate
    assert_site("p((5 in Integer))\n", %w[Integer String], holder: Prism::MatchPredicateNode)
  end

  def test_a_value_in_a_match_predicate_pattern
    assert_site("p((5 in 5))\n", ["5", "6", 1], holder: Prism::MatchPredicateNode)
  end

  def test_a_value_in_a_required_match_pattern
    assert_site("5 => 5\np :matched\n", ["5", "6", 1], holder: Prism::MatchRequiredNode)
  end

  def test_a_required_match
    assert_site("5 => y\np y\n", ["5 => y", "6 => y"], holder: Prism::MatchRequiredNode)
  end
end
