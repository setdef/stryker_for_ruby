# frozen_string_literal: true

require_relative "support/release_script_case"

# The publish step of .github/scripts/release.sh: the GitHub release of a tag
# at a commit, made from the files the build step left.
class ReleasePublishScriptTest < Minitest::Test
  include ReleaseScriptCase

  def setup
    super
    @sha = commit_with("One.")
    @other = commit_with("One.", "Two.")
    push_trunk
    write("release/stryker_for_ruby-0.1.0.gem", "gem")
    write("release-notes.md", "### Added\n\n- One.\n")
  end

  def test_a_new_tag_gets_a_release_that_makes_the_tag_at_the_commit
    script("publish", publish_environment)

    assert_match(%r{\Arelease create v0.1.0 --repo setdef/stryker_for_ruby --target #{@sha} }, gh_log)
    assert_includes(gh_log, "--title Stryker (for Ruby) 0.1.0 --notes-file ")
    assert_match(%r{release/stryker_for_ruby-0.1.0.gem\n\z}, gh_log)
  end

  def test_a_tag_at_the_commit_gets_a_release
    git(@work, "push", "--quiet", "origin", "#{@sha}:refs/tags/v0.1.0")

    script("publish", publish_environment)

    assert_match(/\Arelease create v0.1.0 /, gh_log)
  end

  def test_an_annotated_tag_at_the_commit_gets_a_release
    git(@work, "tag", "--annotate", "--message", "v0.1.0", "v0.1.0", @sha)
    git(@work, "push", "--quiet", "origin", "v0.1.0")

    script("publish", publish_environment)

    assert_match(/\Arelease create v0.1.0 /, gh_log)
  end

  def test_a_tag_at_another_commit_ends_the_run
    git(@work, "push", "--quiet", "origin", "#{@other}:refs/tags/v0.1.0")

    out = failing_script("publish", publish_environment)

    assert_match(/v0.1.0 exists already, at #{@other}, not #{@sha}/, out)
    assert_equal("", gh_log)
  end

  def test_a_release_github_refuses_ends_the_run
    File.write(File.join(@dir, "gh.fail_create"), "")

    failing_script("publish", publish_environment)

    assert_includes(gh_log, "release create v0.1.0")
  end

  private def publish_environment
    { TAG: "v0.1.0", COMMIT: @sha, VERSION: "0.1.0" }
  end
end
