# frozen_string_literal: true

require_relative "support/build_cop_script_case"

# When .github/scripts/build-cop.sh can start ci.yml on a branch, and how it
# tells GitHub's listing of the run it started: the commit's own copy of ci.yml
# must have workflow_dispatch, or GitHub refuses the dispatch and the cop's run
# goes red every half hour.
class BuildCopBisectDispatchScriptTest < Minitest::Test
  include BuildCopScriptCase

  # The tip of trunk may have a ci.yml that the commit does not.
  def test_a_commits_own_copy_of_ci_decides_that_it_can_be_run_on_a_branch
    old = bisect_commit(WITH_DISPATCH)
    bisect_commit(WITHOUT_DISPATCH)
    cop_bisecting(old)

    assert_includes(gh_log, "workflow run ci.yml --ref bisect/#{old}")
  end

  def test_a_commits_own_copy_of_ci_decides_that_it_cannot_be_run_on_a_branch
    old = bisect_commit(WITHOUT_DISPATCH)
    bisect_commit(WITH_DISPATCH)

    assert_match(/::warning::.*workflow_dispatch/, cop_bisecting(old))
  end

  # The first commit of the repository has no ci.yml at all.
  def test_a_commit_with_no_ci_is_left_for_a_person
    first = git(@work, "rev-list", "--max-parents=0", "HEAD").strip
    pushed_commit("feat: x")

    assert_match(/::warning::.*workflow_dispatch/, cop_bisecting(first))
  end

  def test_a_dispatch_that_is_only_mentioned_is_no_dispatch
    mentioned = bisect_commit("#{WITHOUT_DISPATCH}  # workflow_dispatch: later\n")

    assert_match(/::warning::.*workflow_dispatch/, cop_bisecting(mentioned))
  end

  def test_a_dispatch_that_fails_is_an_error
    File.write(File.join(@dir, "gh.fail_dispatch"), "")

    assert_match(/::error::GitHub did not start ci.yml on bisect/, failing_bisect(bisect_commit(WITH_DISPATCH)))
  end

  def test_it_says_which_run_it_started_once_github_lists_it
    File.write(File.join(@dir, "gh.live"), "4242\n")

    assert_match(/Started 4242 of ci.yml on bisect/, cop(bisect_commit(WITH_DISPATCH), "bisect"))
  end

  def test_it_asks_for_the_run_no_more_once_github_lists_it
    File.write(File.join(@dir, "gh.live"), "4242\n")
    cop(bisect_commit(WITH_DISPATCH), "bisect", BUILD_COP_LIST_TRIES: "3", BUILD_COP_LIST_PAUSE: "0")

    assert_equal(1, listings)
  end

  def test_it_asks_again_while_github_does_not_list_the_run
    out = cop(bisect_commit(WITH_DISPATCH), "bisect", BUILD_COP_LIST_TRIES: "3", BUILD_COP_LIST_PAUSE: "0")

    assert_equal([3, true], [listings, out.include?("Started a run of ci.yml")])
  end

  private def listings
    gh_log.lines.count { |line| line.include?("databaseId,conclusion") }
  end
end
