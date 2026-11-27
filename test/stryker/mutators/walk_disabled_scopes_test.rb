# frozen_string_literal: true

require_relative("../../support/disabled_walk")
require_relative("../../test_helper")

# Checks the names, the restore comment, and the grammar of a disable comment.
class WalkDisabledScopesTest < Minitest::Test
  include DisabledWalk

  def test_a_restore_comment_turns_the_mutators_back_on_from_its_line
    source = "# Stryker disable Nines\nx = 1\n# Stryker restore Nines\ny = 2\n"

    assert_equal(["2"], live(source))
    assert_equal(["1"], ignored(source).map(&:first))
  end

  def test_a_restore_comment_for_other_mutators_leaves_the_disabled_ones_off
    source = "# Stryker disable Nines\n# Stryker restore Zeros\nx = 1\n"

    assert_empty(live(source))
  end

  def test_all_turns_off_and_restores_every_mutator
    source = "# Stryker disable all\nx = 1\n# Stryker restore all\ny = 2\n"

    assert_equal(["2"], live(source, nines, integers("Zeros", "0")).uniq)
  end

  def test_the_latest_comment_that_covers_a_mutant_decides
    source = "# Stryker restore all\n# Stryker disable all: first\n# Stryker restore Nines\n" \
      "# Stryker disable next-line Nines: last\nx = 1\n"

    assert_equal([%w[1 Ignored last]], ignored(source))
  end

  def test_a_next_line_restore_turns_the_mutators_back_on_for_that_line_only
    source = "# Stryker disable all\n# Stryker restore next-line all\nx = 1\ny = 2\n"

    assert_equal(["1"], live(source))
    assert_equal(["2"], ignored(source).map(&:first))
  end

  def test_names_match_without_regard_to_letter_case_and_a_list_may_have_spaces
    source = "# Stryker disable next-line nINES , Zeros\nx = 1\n"

    assert_empty(live(source, nines))
    assert_equal(1, ignored(source).size)
  end

  def test_a_comment_names_the_mutators_it_covers_and_leaves_the_others_live
    source = "# Stryker disable next-line Zeros\nx = 1\n"
    found = walk(source, nines, integers("Zeros", "0"))

    assert_equal(%w[Nines], found.mutants.map(&:mutator_name))
    assert_equal(%w[Zeros], found.ignored.map { |result| result.mutant.mutator_name })
  end

  def test_the_pattern_allows_no_space_after_the_hash
    assert_empty(live("#Stryker disable next-line Nines\nx = 1\n"))
  end

  def test_a_comment_that_does_not_match_the_pattern_is_an_ordinary_comment
    ["# @stryker disable next-line all", "#  Stryker disable next-line all", "# Stryker disable"].each do |comment|
      assert_equal(["1"], live("#{comment}\nx = 1\n"), comment)
    end
  end

  def test_next_line_with_a_space_names_one_unknown_mutator_so_the_mutants_stay_live
    source = "# Stryker disable next line Nines\nx = 1\n"
    _, err = capture_io { assert_equal(["1"], live(source)) }

    assert_match(%r{\Alib/a.rb:1: warning: .*"next line Nines"}, err)
  end

  def test_a_name_that_no_mutator_has_writes_a_warning_with_the_file_and_the_line_and_the_rest_applies
    source = "x = a\n# Stryker disable next-line Nope, Nines\ny = 1\n"
    out, err = capture_io { assert_empty(live(source)) }

    assert_empty(out)
    assert_equal(1, err.lines.size)
    assert_match(
      %r{\Alib/a.rb:2: warning: Stryker \(for Ruby\) has no mutator named "Nope", .*valid names are Nines\.},
      err
    )
  end

  def test_names_that_every_mutator_has_write_no_warning
    _, err = capture_io { live("# Stryker disable next-line nines, ALL\nx = 1\n") }

    assert_empty(err)
  end
end
