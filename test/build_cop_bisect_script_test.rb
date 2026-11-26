# frozen_string_literal: true

require_relative "support/build_cop_script_case"

# The bisect and none steps of .github/scripts/build-cop.sh: it pushes a
# commit to a branch and starts ci.yml there, once, and deletes its branches
# when nothing is red.
class BuildCopBisectScriptTest < Minitest::Test
  include BuildCopScriptCase

  def test_it_bisects_on_a_branch_and_starts_ci_there
    bad = bisect_commit(WITH_DISPATCH)
    cop_bisecting(bad)

    assert_includes(origin_branches, "bisect/#{bad}")
    assert_includes(gh_log, "workflow run ci.yml --ref bisect/#{bad}")
  end

  # Issue 18: GitHub refuses the push of a bisect branch made with the run's
  # own token, "refusing to allow a GitHub App to create or update workflow
  # .github/workflows/ci.yml without workflows permission".
  def test_it_pushes_with_the_apps_token_only
    out = failing_bisect(bisect_commit(WITH_DISPATCH), BUILD_COP_PUSH_TOKEN: "")

    assert_match(/BUILD_COP_PUSH_TOKEN is not set/, out)
    assert_empty(origin_branches.strip)
  end

  def test_it_starts_no_run_without_the_apps_token
    failing_bisect(bisect_commit(WITH_DISPATCH), BUILD_COP_PUSH_TOKEN: "")

    refute_includes(gh_log, "workflow run")
  end

  # Outside GitHub Actions, which sets the variable, the task reads the
  # repository the script pushes to.
  def test_it_gives_the_task_the_repository_it_pushes_to
    out = cop(pushed_commit("feat: x"), "wait", GITHUB_REPOSITORY: nil)

    assert_match(%r{^wait \h+: setdef/stryker_for_ruby$}, out)
  end

  def test_it_deletes_the_bisect_branches_when_nothing_is_red
    bad = bisect_commit(WITH_DISPATCH)
    git(@work, "push", "--quiet", "origin", "#{bad}:refs/heads/bisect/#{bad}")
    cop(bad, "none")

    assert_empty(origin_branches.strip)
  end

  # A commit from before ci.yml could be started by hand cannot be run on a
  # branch: GitHub refuses the dispatch, and the cop's own run would go red
  # every half hour.
  def test_a_commit_whose_ci_cannot_be_started_by_hand_is_left_for_a_person
    out = cop_bisecting(bisect_commit(WITHOUT_DISPATCH))

    assert_match(/::warning::.*workflow_dispatch/, out)
    assert_empty(origin_branches.strip)
  end

  # GitHub may take minutes to list a run it was asked to start, and the next
  # call, which finds no run of the commit, says to bisect it again.
  def test_a_run_that_is_not_listed_yet_is_not_started_twice
    bad = bisect_commit(WITH_DISPATCH)
    cop_bisecting(bad)
    File.delete(File.join(@dir, "gh.log"))
    out = cop_bisecting(bad)

    assert_match(/not listed/, out)
    refute_includes(gh_log, "workflow run")
  end

  def test_a_run_that_was_cancelled_is_started_again
    bad = bisect_commit(WITH_DISPATCH)
    cop_bisecting(bad)
    File.write(File.join(@dir, "gh.any"), "1\n")
    File.delete(File.join(@dir, "gh.log"))
    cop_bisecting(bad)

    assert_includes(gh_log, "workflow run ci.yml --ref bisect/#{bad}")
    assert_includes(origin_branches, "bisect/#{bad}")
  end

  # A branch with no run to come would make every later call wait.
  def test_a_dispatch_that_fails_leaves_no_branch_behind
    bad = bisect_commit(WITH_DISPATCH)
    File.write(File.join(@dir, "gh.fail_dispatch"), "")
    failing_bisect(bad)

    assert_empty(origin_branches.strip)
  end
end
