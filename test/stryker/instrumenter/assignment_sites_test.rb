# frozen_string_literal: true

require_relative("../../test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../../support/site_case")

# Checks the assignment and parameter sites from the placement table.
class AssignmentSitesTest < Minitest::Test
  include SiteCase

  def test_one_value_on_the_right_of_a_multiple_assignment
    assert_site("a, b = 1, 3\np [a, b]\n", %w[1 2])
  end

  def test_the_whole_bare_right_side_of_a_multiple_assignment
    assert_site("a, b = 1, 2\np [a, b]\n", ["1, 2", "2, 1"])
  end

  def test_a_whole_multiple_assignment
    assert_site("a = 1\nb = 2\na, b = b, a\np [a, b]\n", ["a, b = b, a", "a, b = a, b"])
  end

  def test_the_right_side_of_an_or_assignment
    assert_site("a = nil\na ||= 1\np a\n", %w[1 2])
  end

  def test_the_right_side_of_an_operator_assignment
    assert_site("a = 1\na += 1\np a\n", ["1", "2", 1])
  end

  def test_a_whole_operator_assignment
    assert_site("a = 1\na += 1\np a\n", ["a += 1", "a -= 1"])
  end

  def test_a_whole_or_assignment
    assert_site("a = nil\na ||= 1\np a\n", ["a ||= 1", "a ||= 2"])
  end

  def test_a_whole_and_assignment
    assert_site("a = 1\na &&= 2\np a\n", ["a &&= 2", "a &&= 3"])
  end

  def test_a_whole_index_or_assignment
    assert_site("h = {}\nh[:k] ||= 1\np h\n", ["h[:k] ||= 1", "h[:k] ||= 2"])
  end

  def test_code_in_a_file_that_ends_with_end
    assert_site("p 1\np DATA.read\n__END__\ndata\n", %w[1 2])
  end

  def test_the_default_value_of_a_positional_parameter
    assert_site("def f(a = 1)\n  a\nend\np f\n", %w[1 2])
  end

  def test_the_default_value_of_a_keyword_parameter
    assert_site("def f(a: 1)\n  a\nend\np f\n", %w[1 2])
  end

  def test_the_default_value_of_a_block_parameter
    assert_site("p([1].map { |x, y = 1| x + y })\n", ["1", "2", 1])
  end

  def test_the_default_value_of_a_lambda_parameter
    assert_site("l = ->(a = 1) { a }\np l.()\n", %w[1 2])
  end

  def test_a_default_value_that_refers_to_an_earlier_parameter
    assert_site("def f(a, b = a + 1)\n  b\nend\np f(1)\n", ["a + 1", "a - 1"])
  end

  def test_removing_a_default
    assert_site("def f(a = 1)\n  a\nend\np f\n", ["a = 1", "a"])
  end
end
