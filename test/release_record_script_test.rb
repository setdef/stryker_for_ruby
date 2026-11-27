# frozen_string_literal: true

require_relative "support/release_script_case"

# The record step of .github/scripts/release.sh: one commit on trunk that dates
# the release's changelog section and raises the version, however far trunk has
# moved since the tagged commit.
class ReleaseRecordScriptTest < Minitest::Test
  include ReleaseScriptCase

  def setup
    super
    @sha = commit_with("One.", "Two.")
    push_trunk
    commit_with("One.", "Two.", "Three.")
    push_trunk
  end

  def test_it_pushes_one_commit_that_files_the_release_and_raises_the_version
    before = origin_head
    script("record", COMMIT: @sha, VERSION: "0.1.0")
    changed = git(@dir, "--git-dir", @origin, "diff", "--name-only", before, "trunk").split

    assert_equal([CHANGELOG, VERSION_FILE, *LOCKFILES].sort, changed.sort)
    assert_equal("1\n", git(@dir, "--git-dir", @origin, "rev-list", "--count", "#{before}..trunk"))
  end

  def test_the_commit_follows_the_conventions_of_the_project
    script("record", COMMIT: @sha, VERSION: "0.1.0")
    subject = git(@dir, "--git-dir", @origin, "log", "-1", "--format=%s", "trunk")

    assert_equal("chore: record v0.1.0 in the changelog\n", subject)
  end

  def test_what_trunk_gained_since_the_tagged_commit_stays_unreleased
    script("record", COMMIT: @sha, VERSION: "0.1.0")
    text = git(@dir, "--git-dir", @origin, "show", "trunk:CHANGELOG.md")

    assert_includes(text, "## [Unreleased]\n\n### Added\n\n- Three.\n\n## [0.1.0] - ")
  end

  def test_a_release_trunk_records_already_is_recorded_no_more
    script("record", COMMIT: @sha, VERSION: "0.1.0")
    before = origin_head

    assert_match(/Trunk records v0.1.0 already/, script("record", COMMIT: @sha, VERSION: "0.1.0"))
    assert_equal(before, origin_head)
  end

  def test_it_needs_the_token_to_push
    out = failing_script("record", COMMIT: @sha, VERSION: "0.1.0", RELEASE_PUSH_TOKEN: nil)

    assert_match(/RELEASE_PUSH_TOKEN is not set/, out)
  end
end
