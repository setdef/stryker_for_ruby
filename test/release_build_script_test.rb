# frozen_string_literal: true

require "rubygems/package"
require_relative "support/release_script_case"

# The build and publish steps of .github/scripts/release.sh: the gem built from
# a commit with the tag's version written into it, its checksums and notes, and
# the release made from them.
class ReleaseBuildScriptTest < Minitest::Test
  include ReleaseScriptCase

  def setup
    super
    @sha = commit_with("One.", "Two.")
    commit_with("One.", "Two.", "Three.")
    push_trunk
  end

  def test_it_builds_the_gem_of_the_commit_with_the_version_of_the_tag
    script("build", COMMIT: @sha, VERSION: "0.1.0")
    spec = Gem::Package.new(File.join(@work, "release", "stryker_for_ruby-0.1.0.gem")).spec

    assert_equal(["stryker_for_ruby", "0.1.0"], [spec.name, spec.version.to_s])
  end

  def test_it_leaves_the_working_copy_and_the_version_file_of_trunk_alone
    script("build", COMMIT: @sha, VERSION: "0.1.0")

    assert_equal(version_file("0.0.0"), working_copy(VERSION_FILE))
    refute_includes(git(@work, "worktree", "list"), "release")
  end

  def test_it_writes_the_checksums_the_release_lists
    script("build", COMMIT: @sha, VERSION: "0.1.0")
    sums = File.read(File.join(@work, "release", "SHA256SUMS"))
    gem = File.join(@work, "release", "stryker_for_ruby-0.1.0.gem")

    assert_equal("#{Digest::SHA256.file(gem).hexdigest}  stryker_for_ruby-0.1.0.gem\n", sums)
  end

  def test_the_notes_are_the_entries_of_the_commit_not_of_the_tip
    script("build", COMMIT: @sha, VERSION: "0.1.0")

    assert_equal("### Added\n\n- One.\n- Two.\n", File.read(File.join(@work, "release-notes.md")))
  end

  def test_a_commit_that_lists_nothing_ends_the_run
    empty = commit_with
    push_trunk

    assert_match(/lists nothing new/, failing_script("build", COMMIT: empty, VERSION: "0.1.0"))
  end

  def test_it_creates_the_release_of_the_tag_at_the_commit_with_its_files
    script("build", COMMIT: @sha, VERSION: "0.1.0")
    script("publish", TAG: "v0.1.0", COMMIT: @sha, VERSION: "0.1.0")

    assert_match(%r{\Arelease create v0.1.0 --repo setdef/stryker_for_ruby --target #{@sha} }, gh_log)
    assert_includes(gh_log, "--title Stryker (for Ruby) 0.1.0 --notes-file ")
    assert_match(%r{release/SHA256SUMS \S*release/stryker_for_ruby-0.1.0.gem\n\z}, gh_log)
  end

  def test_a_tag_that_exists_ends_the_run
    git(@work, "push", "--quiet", "origin", "#{@sha}:refs/tags/v0.1.0")

    assert_match(/v0.1.0 exists already/, failing_script("publish", TAG: "v0.1.0", COMMIT: @sha, VERSION: "0.1.0"))
    assert_equal("", gh_log)
  end

  def test_a_release_github_refuses_ends_the_run
    File.write(File.join(@dir, "gh.fail_create"), "")
    script("build", COMMIT: @sha, VERSION: "0.1.0")

    failing_script("publish", TAG: "v0.1.0", COMMIT: @sha, VERSION: "0.1.0")

    assert_includes(gh_log, "release create v0.1.0")
  end
end
