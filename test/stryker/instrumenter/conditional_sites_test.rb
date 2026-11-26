# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/site_case")

# Checks the sites in a condition that hold a regexp literal or a flip-flop,
# from the conditions and loops table of the placement design. Each switch
# must go on the whole conditional, where the construct stays in the
# condition.
class ConditionalSitesTest < Minitest::Test
  include SiteCase

  def test_a_regexp_literal_under_a_not_in_a_condition
    assert_regexp_condition("p :y if !/foo/\n")
  end

  def test_a_regexp_literal_under_the_keyword_not_in_a_condition
    assert_regexp_condition("p :y if not /foo/\n")
  end

  def test_a_regexp_literal_under_an_and_in_a_condition
    assert_regexp_condition("t = true\np :y if /foo/ && t\n")
  end

  def test_a_regexp_literal_under_an_or_in_a_condition
    assert_regexp_condition("t = false\np :y if t || /foo/\n")
  end

  def test_a_regexp_literal_under_the_keyword_and_in_a_condition
    assert_regexp_condition("t = true\np :y if /foo/ and t\n")
  end

  def test_a_regexp_literal_under_the_keyword_or_in_a_condition
    assert_regexp_condition("t = false\np :y if t or /foo/\n")
  end

  def test_a_regexp_literal_in_parentheses_under_a_not_in_a_condition
    assert_regexp_condition("p :y if !(/foo/)\n")
  end

  def test_an_interpolated_regexp_under_a_not_in_a_condition
    source = "$_ = 'foo'\ns = 'fo'\np :y if !/\#{s}o/\np :done\n"

    assert_site(source, ["/\#{s}o/", "/\#{s}x/"], holder: Prism::IfNode)
  end

  def test_a_flip_flop_under_an_and
    source = "r = []\n(1..6).each { |i| r << i if ((i == 2)..(i == 4)) && true }\np r\n"

    assert_site(source, ["&&", "||"], holder: Prism::IfNode)
  end

  def test_an_integer_endpoint_of_a_flip_flop
    source = "r = []\n(1..6).each { |i| $. = i; r << i if 2..4 }\np r\n"

    assert_site(source, %w[2 3], holder: Prism::IfNode, warnings: false)
  end

  # Checks a mutant of the regexp literal /foo/ in +statement+, which tests a
  # condition that holds it. Ruby warns about the literal once for each branch
  # of the switch.
  def assert_regexp_condition(statement)
    assert_site("$_ = 'foo'\n#{statement}p :done\n", ["/foo/", "/bar/"], holder: Prism::IfNode, warnings: false)
  end
end
