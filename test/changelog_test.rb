# frozen_string_literal: true

require_relative "test_helper"

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative "../tasks/changelog"

# tasks/changelog.rb: what the release workflow reads from CHANGELOG.md and
# writes back to it.
class ChangelogTest < Minitest::Test
  DAY = Date.new(2026, 11, 26)
  private_constant(:DAY)

  LOG = <<~MD
    # Changelog

    ## [Unreleased]

    ### Added

    - A new thing.
    - Another thing,
      which runs over two lines.

    ### Fixed

    - A bug.

    ## [0.1.0] - 2026-11-01

    ### Added

    - The first thing.
  MD
  private_constant(:LOG)

  def test_it_lists_the_entries_of_unreleased_with_their_continuation_lines
    texts = Changelog.new(LOG).unreleased.map(&:text)

    assert_equal(["- A new thing.", "- Another thing,\n  which runs over two lines.", "- A bug."], texts)
  end

  def test_an_entry_knows_the_heading_it_is_listed_under
    assert_equal(["### Added", "### Added", "### Fixed"], Changelog.new(LOG).unreleased.map(&:heading))
  end

  def test_prose_that_is_no_entry_is_no_entry
    log = Changelog.new("## [Unreleased]\n\nSome prose.\n  indented prose.\n\n- Item\n\n  more of it\n")

    assert_equal(["- Item\n\n  more of it"], log.unreleased.map(&:text))
  end

  def test_a_changelog_with_no_unreleased_section_is_malformed
    error = assert_raises(Changelog::Malformed) { Changelog.new("# Changelog\n").unreleased }

    assert_match(/no ## \[Unreleased\] section/, error.message)
  end

  def test_it_ends_a_last_line_that_has_no_newline
    assert_equal("## [Unreleased]\n- Item\n", Changelog.new("## [Unreleased]\n- Item").to_s)
  end

  def test_added_leaves_out_the_entries_the_previous_release_listed
    entries = Changelog.new(LOG).unreleased
    previous = entries.first(1)

    assert_equal(entries.drop(1), Changelog.added(entries, previous))
  end

  def test_an_entry_listed_twice_and_once_before_is_added_once
    entry = Changelog::Entry.new("### Added", "- Same.")

    assert_equal([entry], Changelog.added([entry, entry], [entry]))
  end

  def test_body_puts_each_heading_once_above_its_entries
    entries = [
      Changelog::Entry.new("### Added", "- One."),
      Changelog::Entry.new("### Fixed", "- Two."),
      Changelog::Entry.new("### Added", "- Three."),
    ]

    assert_equal("### Added\n\n- One.\n- Three.\n\n### Fixed\n\n- Two.\n", Changelog.body(entries))
  end

  def test_body_lists_entries_that_have_no_heading_as_they_are
    assert_equal("- One.\n", Changelog.body([Changelog::Entry.new(nil, "- One.")]))
  end

  def test_record_files_the_entries_under_a_dated_section_above_the_older_ones
    log = Changelog.new(LOG)
    entries = log.unreleased
    recorded = log.record("0.2.0", DAY, entries, entries).to_s

    assert_equal(<<~MD, recorded)
      # Changelog

      ## [Unreleased]

      ## [0.2.0] - 2026-11-26

      ### Added

      - A new thing.
      - Another thing,
        which runs over two lines.

      ### Fixed

      - A bug.

      ## [0.1.0] - 2026-11-01

      ### Added

      - The first thing.
    MD
  end

  def test_record_keeps_what_trunk_gained_since_the_tagged_commit
    tagged = Changelog.new(LOG).unreleased
    trunk = Changelog.new(LOG.sub("- A bug.\n", "- A bug.\n- A later bug.\n"))
    recorded = trunk.record("0.2.0", DAY, tagged, tagged).to_s

    assert_includes(recorded, "## [Unreleased]\n\n### Fixed\n\n- A later bug.\n\n## [0.2.0] - 2026-11-26\n")
    assert_equal(["- A later bug."], Changelog.new(recorded).unreleased.map(&:text))
  end

  def test_record_files_a_section_below_a_newer_one
    log = Changelog.new(LOG.sub("## [0.1.0]", "## [0.3.0] - 2026-11-20\n\n- Newer.\n\n## [0.1.0]"))
    entries = log.unreleased
    versions = log.record("0.2.0", DAY, entries, entries).to_s.scan(/^## \[(\S+)\]/).flatten

    assert_equal(%w[Unreleased 0.3.0 0.2.0 0.1.0], versions)
  end

  def test_record_files_the_first_release_below_unreleased_alone
    log = Changelog.new("## [Unreleased]\n\n- Item\n")
    entries = log.unreleased

    recorded = log.record("0.1.0", DAY, entries, entries).to_s

    assert_equal("## [Unreleased]\n\n## [0.1.0] - 2026-11-26\n\n- Item\n", recorded)
  end

  def test_recording_a_release_twice_records_it_once
    log = Changelog.new(LOG)
    entries = log.unreleased
    once = log.record("0.2.0", DAY, entries, entries)

    assert_same(once, once.record("0.2.0", DAY, entries, entries))
  end
end
