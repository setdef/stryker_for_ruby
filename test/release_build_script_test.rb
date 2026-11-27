# frozen_string_literal: true

require "rubygems/package"
require_relative "support/release_script_case"

# The build step of .github/scripts/release.sh: the gem built from a commit
# with the tag's version written into it, its checksums and notes.
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
end
