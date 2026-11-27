# frozen_string_literal: true

require_relative "support/release_repository"

# tasks/release.rb: the version a tag releases, and a release's notes, read
# from a repository of commits and tags.
class ReleaseTest < Minitest::Test
  include ReleaseRepository

  def test_a_tag_of_three_plain_integers_releases_its_version
    assert_equal("0.12.3", release.version("v0.12.3", commit_with("one")))
  end

  def test_a_tag_that_is_not_v0_x_y_is_refused
    ["0.1.0", "v1.0.0", "v0.1", "v0.1.0.1", "v0.01.0", "v0.1.0-rc1", "v0.1.x"].each do |name|
      error = assert_raises(Release::Refusal, name) { release.version(name, commit_with("one")) }

      assert_match(/is not v0.X.Y, with three plain integers/, error.message)
    end
  end

  def test_a_tag_that_exists_at_the_commit_releases_its_version
    sha = commit_with("one")
    tag("v0.1.0", sha)

    assert_equal("0.1.0", release.version("v0.1.0", sha))
  end

  def test_an_annotated_tag_at_the_commit_releases_its_version
    sha = commit_with("one")
    git(@work, "tag", "--annotate", "--message", "v0.1.0", "v0.1.0", sha)

    assert_equal("0.1.0", release.version("v0.1.0", sha))
  end

  def test_a_tag_that_exists_at_another_commit_is_refused
    tagged = commit_with("one")
    tag("v0.1.0", tagged)
    other = commit_with("one", "two")
    error = assert_raises(Release::Refusal) { release.version("v0.1.0", other) }

    assert_match(/v0.1.0 exists already, at #{tagged}, not #{other}/, error.message)
  end

  def test_a_tag_that_exists_is_no_release_before_itself
    sha = commit_with("one")
    tag("v0.1.0", sha)
    tag("v0.2.0", sha)

    assert_equal("0.2.0", release.version("v0.2.0", sha))
  end

  def test_a_tag_that_exists_is_still_refused_when_a_newer_release_exists
    sha = commit_with("one")
    tag("v0.1.0", sha)
    tag("v0.2.0", sha)
    error = assert_raises(Release::Refusal) { release.version("v0.1.0", sha) }

    assert_match(/v0.1.0 is not newer than v0.2.0/, error.message)
  end

  def test_a_tag_not_newer_than_every_release_is_refused
    sha = commit_with("one")
    tag("v0.2.0", sha)
    tag("v0.10.0", sha)
    error = assert_raises(Release::Refusal) { release.version("v0.9.0", sha) }

    assert_match(/v0.9.0 is not newer than v0.10.0/, error.message)
    assert_equal("0.11.0", release.version("v0.11.0", sha))
  end

  def test_tags_that_are_no_release_are_not_releases
    sha = commit_with("one")
    tag("v1.0.0", sha)
    tag("vNext", sha)

    assert_equal("0.0.1", release.next_version)
    assert_equal("0.1.0", release.version("v0.1.0", sha))
  end

  def test_the_next_version_raises_the_patch_of_the_newest_release
    tag("v0.4.9", commit_with("one"))

    assert_equal("0.4.10", release.next_version)
  end

  def test_the_notes_are_the_entries_of_unreleased
    sha = commit_with("One.", "Two.")

    assert_equal("### Added\n\n- One.\n- Two.\n", release.notes(sha))
  end

  def test_the_notes_leave_out_what_the_release_before_listed
    tag("v0.1.0", commit_with("One."))
    sha = commit_with("One.", "Two.")

    assert_equal("### Added\n\n- Two.\n", release.notes(sha))
  end

  def test_a_commit_that_adds_nothing_has_no_notes
    tag("v0.1.0", commit_with("One."))
    error = assert_raises(Release::Refusal) { release.notes(commit_with("One.")) }

    assert_match(/lists nothing new since v0.1.0/, error.message)
  end

  def test_a_commit_before_any_release_that_lists_nothing_has_no_notes
    error = assert_raises(Release::Refusal) { release.notes(commit_with) }

    assert_match(/lists nothing new since the start/, error.message)
  end

  def test_a_tag_on_the_commit_is_not_the_release_before_it
    sha = commit_with("One.")
    tag("v0.1.0", sha)

    assert_equal("### Added\n\n- One.\n", release.notes(sha))
  end

  def test_the_notes_of_a_release_whose_tag_is_on_the_commit_leave_out_the_release_before_it
    tag("v0.1.0", commit_with("One."))
    sha = commit_with("One.", "Two.")
    tag("v0.2.0", sha)

    assert_equal("### Added\n\n- Two.\n", release.notes(sha))
  end

  def test_a_commit_with_no_changelog_is_refused
    error = assert_raises(Release::Refusal) { release.notes(git(@work, "rev-parse", "HEAD").strip) }

    assert_match(/git show .*CHANGELOG.md failed/, error.message)
  end
end
