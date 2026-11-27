# frozen_string_literal: true

require_relative "support/release_repository"

# tasks/release.rb: what a release writes into the working copy, which is
# trunk as it stands after the release.
class ReleaseRecordTest < Minitest::Test
  include ReleaseRepository

  DAY = Date.new(2026, 11, 26)
  private_constant(:DAY)

  def test_the_version_is_written_into_the_version_file
    commit_with("One.")
    release.stamp("0.3.0")

    assert_equal(version_file("0.3.0"), working_copy(VERSION_FILE))
  end

  def test_a_version_file_with_no_version_is_refused
    commit_with("One.")
    File.write(File.join(@work, VERSION_FILE), "module Stryker\nend\n")
    error = assert_raises(Release::Refusal) { release.stamp("0.3.0") }

    assert_match(/has no VERSION/, error.message)
  end

  def test_recording_files_the_entries_the_tagged_commit_held_and_raises_the_version
    tagged = commit_with("One.", "Two.")
    commit_with("One.", "Two.", "Three.")
    release.record("0.1.0", tagged, DAY)

    assert_includes(working_copy(CHANGELOG), "## [Unreleased]\n\n### Added\n\n- Three.\n\n## [0.1.0] - 2026-11-26\n")
    assert_includes(working_copy(CHANGELOG), "\n- One.\n- Two.\n")
    assert_equal(version_file("0.1.0"), working_copy(VERSION_FILE))
  end

  def test_recording_raises_the_gem_in_every_lockfile_and_no_other_gem
    tagged = commit_with("One.")
    release.record("0.1.0", tagged, DAY)

    other_gem_unchanged = lockfile("0.1.0").sub("stryker_for_ruby_extras (0.1.0)", "stryker_for_ruby_extras (0.0.0)")

    assert_equal([other_gem_unchanged] * 2, LOCKFILES.map { |name| working_copy(name) })
  end

  def test_recording_never_lowers_the_version
    tagged = commit_with("One.")
    commit_with("One.", version: "0.2.0")
    release.record("0.1.0", tagged, DAY)

    assert_equal(version_file("0.2.0"), working_copy(VERSION_FILE))
    assert_equal(lockfile("0.2.0"), working_copy(LOCKFILES.first))
  end

  def test_recording_a_commit_that_has_its_tag_lists_the_same_entries
    tagged = commit_with("One.", "Two.")
    tag("v0.1.0", tagged)
    release.record("0.1.0", tagged, DAY)

    assert_includes(working_copy(CHANGELOG), "## [0.1.0] - 2026-11-26\n\n### Added\n\n- One.\n- Two.\n")
  end
end
