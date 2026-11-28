# frozen_string_literal: true

require_relative "support/build_cop_script_case"

# What .github/scripts/build-cop.sh does when it cannot make the revert: a
# commit that later ones built on, and an origin that keeps refusing the push.
# Either way the cop's run goes red, which calls a person.
class BuildCopRevertFailureScriptTest < Minitest::Test
  include BuildCopScriptCase

  # Reverting a commit that a later commit built on conflicts. A person decides
  # what to do, so the cop's run goes red and leaves trunk and the clone as
  # they were.
  def test_a_commit_that_does_not_revert_cleanly_fails_the_run_and_leaves_trunk_alone
    bad = pushed_commit("feat: bad", "shared.txt", "one\n")
    pushed_commit("feat: built on it", "shared.txt", "two\n")
    before = origin_head
    out = failing_cop(bad, "revert", BUILD_COP_REVERT: "true")

    assert_match(%r{::error::#{bad} does not revert cleanly on trunk: setdef/stryker_for_ruby}, out)
    assert_equal(before, origin_head)
  end

  def test_a_commit_that_does_not_revert_cleanly_leaves_no_revert_half_done
    bad = pushed_commit("feat: bad", "shared.txt", "one\n")
    pushed_commit("feat: built on it", "shared.txt", "two\n")
    failing_cop(bad, "revert", BUILD_COP_REVERT: "true")

    assert_empty(git(@work, "status", "--porcelain", "--untracked-files=no"))
    refute_path_exists(File.join(@dir, "gh.log"))
  end

  # A merge commit has no revert without a side to keep, and git fails before it
  # starts one, so that there is nothing to abort.
  def test_a_merge_commit_fails_the_run_as_a_commit_that_does_not_revert_cleanly
    git(@work, "checkout", "--quiet", "-b", "side")
    commit("feat: side", "side.txt", "side\n")
    git(@work, "checkout", "--quiet", "trunk")
    commit("feat: trunk", "trunk.txt", "trunk\n")
    git(@work, "merge", "--quiet", "--no-ff", "-m", "merge side", "side")
    git(@work, "push", "--quiet", "origin", "trunk")
    merge = git(@work, "rev-parse", "HEAD").strip
    out = failing_cop(merge, "revert", BUILD_COP_REVERT: "true")

    assert_match(%r{::error::#{merge} does not revert cleanly on trunk: setdef/stryker_for_ruby}, out)
  end

  # The origin refuses every push, as it does while trunk keeps moving.
  def test_it_fails_the_run_when_trunk_moves_under_every_try_to_push_the_revert
    bad = pushed_commit("feat: bad")
    before = origin_head
    refusing_every_push
    out = failing_cop(bad, "revert", BUILD_COP_REVERT: "true")

    assert_match(/::error::trunk moved under every try to revert #{bad}/, out)
    assert_equal(before, origin_head)
  end

  def test_it_tries_three_times_to_push_the_revert
    bad = pushed_commit("feat: bad")
    refusing_every_push
    failing_cop(bad, "revert", BUILD_COP_REVERT: "true")

    assert_equal(3, File.readlines(File.join(@dir, "pushes")).size)
    refute_path_exists(File.join(@dir, "gh.log"))
  end

  # Has the origin refuse every push to trunk, and write down each one.
  private def refusing_every_push
    File.write(File.join(@origin, "hooks", "pre-receive"), <<~SH, perm: 0o755)
      #!/bin/sh
      echo push >>"#{@dir}/pushes"
      exit 1
    SH
  end
end
