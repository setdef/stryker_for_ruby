# frozen_string_literal: true

require_relative "test_helper"

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative "../tasks/changelog"

# tasks/changelog.rb: the version that [Unreleased]'s link compares with HEAD
# when a release is recorded.
class ChangelogReleaseLinksTest < Minitest::Test
  DAY = Date.new(2026, 11, 26)
  private_constant(:DAY)

  def test_the_link_of_unreleased_keeps_a_prerelease_as_it_was_written
    log = Changelog.new("## [Unreleased]\n\n- Item\n\n[Unreleased]: https://example.test/org/repo/compare/v0.2.0...HEAD\n")
    entries = log.unreleased

    recorded = log.record("0.3.0-rc.1", DAY, entries, entries).to_s

    assert_includes(recorded, "[Unreleased]: https://example.test/org/repo/compare/v0.3.0-rc.1...HEAD\n")
  end

  def test_the_link_of_unreleased_names_the_newest_release_of_all_the_sections
    log = Changelog.new(<<~MD)
      ## [Unreleased]

      - Item

      ## [0.3.0] - 2026-11-20

      - Newer.

      [Unreleased]: https://example.test/org/repo/compare/v0.3.0...HEAD
      [0.3.0]: https://example.test/org/repo/releases/tag/v0.3.0
    MD
    entries = log.unreleased

    assert_includes(log.record("0.2.0", DAY, entries, entries).to_s, "/compare/v0.3.0...HEAD\n")
  end
end
