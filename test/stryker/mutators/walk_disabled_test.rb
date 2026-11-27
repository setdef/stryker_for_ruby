# frozen_string_literal: true

require_relative("../../support/disabled_walk")
require_relative("../../test_helper")

# Checks which mutants a disable comment covers, as the section "The disable comment" of
# docs/contributors/design/mutators.md says.
class WalkDisabledTest < Minitest::Test
  include DisabledWalk

  def test_a_next_line_comment_ignores_the_mutants_of_the_next_line_with_its_reason
    source = "# Stryker disable next-line Nines: the 1 is a flag\nx = 1\ny = 2\n"

    assert_equal([["1", "Ignored", "the 1 is a flag"]], ignored(source))
    assert_equal(["2"], live(source))
  end

  def test_gives_the_status_reason_ignored_using_a_comment_when_the_comment_has_no_reason
    assert_equal(
      [["1", "Ignored", "Ignored using a comment"]],
      ignored("# Stryker disable next-line Nines\nx = 1\n")
    )
  end

  def test_a_next_line_comment_skips_blank_lines_and_comments_to_the_next_line_that_holds_code
    source = "# Stryker disable next-line all\n\n  # a note\n=begin\nnotes\n=end\nx = 1\ny = 2\n"

    assert_equal(["2"], live(source))
  end

  def test_a_next_line_comment_covers_the_mutants_whose_site_starts_on_the_next_code_line
    source = "# Stryker disable next-line all\nx = [\n  1,\n  2\n]\ny = 3\n"
    array = FakeMutator.new("Arrays") do |node, _ancestors|
      node.is_a?(Prism::ArrayNode) ? [Stryker::Edit.over(node.location, "[]")] : []
    end

    assert_equal([["[", "Ignored", "Ignored using a comment"]], ignored(source, array))
    assert_equal(%w[1 2 3], live(source, nines))
  end

  def test_a_comment_without_next_line_ignores_the_rest_of_the_file_from_its_line
    source = "x = 1\n# Stryker disable Nines: generated\ny = 2\nz = 3\n"

    assert_equal(["1"], live(source))
    assert_equal([%w[2 Ignored generated], %w[3 Ignored generated]], ignored(source))
  end

  def test_a_trailing_comment_covers_the_next_line_and_not_its_own
    source = "x = 1 # Stryker disable next-line Nines\ny = 2\n"

    assert_equal(["1"], live(source))
  end

  def test_a_trailing_comment_without_next_line_covers_its_own_line_onward
    assert_empty(live("x = 1 # Stryker disable Nines\ny = 2\n"))
  end

  def test_a_comment_inside_a_string_or_a_heredoc_is_not_a_comment
    source = "s = <<~A\n  # Stryker disable all\nA\nx = 1\ny = \"# Stryker disable all\"\n"

    assert_equal(["1"], live(source))
  end

  def test_a_comment_inside_a_block_comment_is_not_a_comment
    assert_equal(["1"], live("=begin\n# Stryker disable all\n=end\nx = 1\n"))
  end

  def test_a_comment_after_end_of_the_data_is_not_a_comment
    assert_equal(["1"], live("x = 1\n__END__\n# Stryker disable all\n"))
  end

  def test_a_next_line_comment_before_the_end_of_the_file_covers_nothing
    assert_equal(["1"], live("x = 1\n# Stryker disable next-line all\n__END__\ny = 2\n"))
    assert_equal(["1"], live("x = 1\n# Stryker disable next-line all\n"))
  end
end
