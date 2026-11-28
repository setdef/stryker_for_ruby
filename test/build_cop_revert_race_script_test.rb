# frozen_string_literal: true

require_relative "support/build_cop_script_case"

# What .github/scripts/build-cop.sh does when trunk moves while it reverts: the
# origin refuses the push, and what landed meanwhile may be a revert of the
# same commit, which a second revert would undo.
class BuildCopRevertRaceScriptTest < Minitest::Test
  include BuildCopScriptCase

  # The push is refused once, as it is when trunk moves under the cop, and
  # what landed meanwhile is a revert of the same commit.
  def test_a_revert_that_lands_while_the_push_is_refused_is_reverted_no_more
    bad = pushed_commit("feat: bad")
    landing = landing_on_first_refused_push(bad)
    out = cop(bad, "revert", BUILD_COP_REVERT: "true")

    assert_match(/reverted on trunk already as #{landing}/, out)
    assert_equal(landing, origin_head)
    refute_path_exists(File.join(@dir, "gh.log"))
  end

  def test_a_revert_that_landed_first_is_a_line_of_the_summary
    bad = pushed_commit("feat: bad")
    landing_on_first_refused_push(bad)
    summary = File.join(@dir, "summary.txt")
    cop(bad, "revert", BUILD_COP_REVERT: "true", GITHUB_STEP_SUMMARY: summary)

    assert_match(/which landed first; trunk's next green run ends this\.$/, File.read(summary))
  end

  # What landed meanwhile is another commit: the cop reverts on top of it.
  def test_it_reverts_again_on_top_of_what_landed_while_the_push_was_refused
    bad = pushed_commit("feat: bad")
    other = commit("feat: other", "other.txt", "other\n")
    git(@work, "reset", "--quiet", "--hard", bad)
    refusing_first_push_with(other)
    cop(bad, "revert", BUILD_COP_REVERT: "true")
    tree = git(@dir, "--git-dir", @origin, "ls-tree", "--name-only", "trunk")

    assert_includes(git(@dir, "--git-dir", @origin, "log", "-1", "--format=%B", "trunk"), "This reverts commit #{bad}.")
    assert_includes(tree, "other.txt")
    refute_includes(tree, "bad.txt")
  end

  # Makes a revert of +bad+ and has the origin refuse the first push to trunk
  # after moving trunk to it. Returns the revert.
  private def landing_on_first_refused_push(bad)
    git(@work, "revert", "--no-edit", bad)
    landing = git(@work, "rev-parse", "HEAD").strip
    git(@work, "reset", "--quiet", "--hard", bad)
    refusing_first_push_with(landing)
    landing
  end

  # Has the origin refuse the first push to trunk, and move trunk to
  # +landing+, a commit of the clone that is on top of trunk.
  private def refusing_first_push_with(landing)
    git(@work, "push", "--quiet", "origin", "#{landing}:refs/heads/landing")
    File.write(File.join(@origin, "hooks", "pre-receive"), <<~SH, perm: 0o755)
      #!/bin/sh
      [ -f "#{@dir}/refused" ] && exit 0
      touch "#{@dir}/refused"
      unset GIT_QUARANTINE_PATH
      git update-ref refs/heads/trunk refs/heads/landing
      exit 1
    SH
  end
end
