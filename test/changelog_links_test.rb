# frozen_string_literal: true

require_relative "test_helper"

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative "../tasks/changelog"

# tasks/changelog.rb: the link references that recording a release keeps at
# the foot of CHANGELOG.md.
class ChangelogLinksTest < Minitest::Test
  DAY = Date.new(2026, 11, 26)
  private_constant(:DAY)

  LINKED = <<~MD
    ## [Unreleased]

    - Item

    ## [0.1.0] - 2026-11-01

    - Old.

    [Unreleased]: https://example.test/org/repo/compare/v0.1.0...HEAD
    [0.1.0]: https://example.test/org/repo/releases/tag/v0.1.0
  MD
  private_constant(:LINKED)

  def test_record_links_the_release_and_points_unreleased_past_it
    log = Changelog.new(LINKED)
    entries = log.unreleased

    assert_equal(<<~MD, log.record("0.2.0", DAY, entries, entries).to_s)
      ## [Unreleased]

      ## [0.2.0] - 2026-11-26

      - Item

      ## [0.1.0] - 2026-11-01

      - Old.

      [Unreleased]: https://example.test/org/repo/compare/v0.2.0...HEAD
      [0.2.0]: https://example.test/org/repo/releases/tag/v0.2.0
      [0.1.0]: https://example.test/org/repo/releases/tag/v0.1.0
    MD
  end

  def test_record_files_the_first_release_above_the_links
    log = Changelog.new("## [Unreleased]\n\n- Item\n\n[Unreleased]: https://example.test/org/repo/compare/v0.0.0...HEAD\n")
    entries = log.unreleased

    assert_equal(<<~MD, log.record("0.1.0", DAY, entries, entries).to_s)
      ## [Unreleased]

      ## [0.1.0] - 2026-11-26

      - Item

      [Unreleased]: https://example.test/org/repo/compare/v0.1.0...HEAD
      [0.1.0]: https://example.test/org/repo/releases/tag/v0.1.0
    MD
  end

  def test_record_links_a_release_older_than_one_recorded_without_moving_unreleased
    log = Changelog.new(newer_release_recorded)
    entries = log.unreleased
    links = log.record("0.2.0", DAY, entries, entries).to_s.lines.grep(/\A\[/)

    assert_equal(%w[Unreleased 0.3.0 0.2.0 0.1.0], links.map { |line| line[/\A\[([^\]]+)\]/, 1] })
    assert_includes(links, "[Unreleased]: https://example.test/org/repo/compare/v0.3.0...HEAD\n")
  end

  def test_record_adds_the_links_a_recorded_release_lacks
    unlinked = LINKED.sub("v0.1.0...HEAD", "v0.0.1...HEAD").sub(/^\[0\.1\.0\].*\n/, "")
    log = Changelog.new(unlinked)
    entries = log.unreleased

    assert_equal(LINKED, log.record("0.1.0", DAY, entries, entries).to_s)
  end

  def test_record_leaves_a_changelog_whose_links_are_right_as_it_is
    log = Changelog.new(LINKED)
    entries = log.unreleased
    once = log.record("0.2.0", DAY, entries, entries)

    assert_same(once, once.record("0.2.0", DAY, entries, entries))
  end

  def test_record_writes_no_links_where_unreleased_has_none_to_take_the_repository_from
    log = Changelog.new(LINKED.sub(/^\[Unreleased\].*\n/, ""))
    entries = log.unreleased
    links = log.record("0.2.0", DAY, entries, entries).to_s.lines.grep(/\A\[/)

    assert_equal(["[0.1.0]: https://example.test/org/repo/releases/tag/v0.1.0\n"], links)
  end

  private def newer_release_recorded
    LINKED.sub("## [0.1.0]", "## [0.3.0] - 2026-11-20\n\n- Newer.\n\n## [0.1.0]")
      .sub("v0.1.0...HEAD", "v0.3.0...HEAD")
      .sub(/^\[0\.1\.0\]/, "[0.3.0]: https://example.test/org/repo/releases/tag/v0.3.0\n\\0")
  end
end
