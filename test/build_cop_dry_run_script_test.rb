# frozen_string_literal: true

require_relative "support/build_cop_script_case"

# The dry run of .github/scripts/build-cop.sh, which a run by hand is unless it
# is asked otherwise: the task says what to do, the script says what it would
# do, and it pushes nothing, starts nothing, and runs nothing again, whatever
# the step. A dry run has no push token, since the workflow mints none for it.
class BuildCopDryRunScriptTest < Minitest::Test
  include BuildCopScriptCase

  # Reverting is on, so that only the dry run stops a revert.
  DRY = { BUILD_COP_DRY_RUN: "true", BUILD_COP_PUSH_TOKEN: nil, BUILD_COP_REVERT: "true" }.freeze
  private_constant(:DRY)

  def test_a_dry_run_says_what_it_would_do
    out = cop(pushed_commit("feat: bad"), "revert", DRY)

    assert_match(%r{^revert \h+: setdef/stryker_for_ruby$}, out)
    assert_includes(out, "Dry run: did nothing.")
  end

  def test_a_dry_run_reverts_nothing
    bad = pushed_commit("feat: bad")
    before = origin_head
    cop(bad, "revert", DRY)

    assert_equal(before, origin_head)
    refute_path_exists(File.join(@dir, "gh.log"))
  end

  def test_a_dry_run_bisects_nothing
    bad = bisect_commit(WITH_DISPATCH)
    cop(bad, "bisect", DRY)

    assert_empty(origin_branches.strip)
    refute_path_exists(File.join(@dir, "gh.log"))
  end

  def test_a_dry_run_deletes_no_branch
    bad = bisect_commit(WITH_DISPATCH)
    git(@work, "push", "--quiet", "origin", "#{bad}:refs/heads/bisect/#{bad}")
    cop(bad, "none", DRY)

    assert_includes(origin_branches, "bisect/#{bad}")
  end

  def test_a_dry_run_runs_no_job_again
    cop(pushed_commit("feat: x"), "rerun", DRY)

    refute_path_exists(File.join(@dir, "gh.log"))
  end

  # The workflow gives a run that is not a dry one the word false.
  def test_a_run_that_is_not_a_dry_run_reverts
    bad = pushed_commit("feat: bad")
    cop(bad, "revert", DRY.merge(BUILD_COP_DRY_RUN: "false", BUILD_COP_PUSH_TOKEN: "app-token"))

    refute_equal(bad, origin_head)
    assert_match(/\Arevert: feat: bad\n/, git(@dir, "--git-dir", @origin, "log", "-1", "--format=%B", "trunk"))
  end
end
