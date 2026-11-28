# frozen_string_literal: true

require_relative "support/build_cop_case"

# Which runs the build cop counts, and for what (.github/workflows/build-cop.yml
# and tasks/commit_runs.rb): a run on trunk is green when it and every job it
# has succeeded; the newest run that failed names the jobs to judge by; a job
# fails again only on a second attempt; and a run that waits for a person's
# approval has not finished.
class BuildCopRunsTest < Minitest::Test
  include BuildCopCase

  # A run that a person started by hand, as the cop starts those on its bisect
  # branches, checks out its commit like a push does.
  def test_a_run_started_by_hand_counts_like_a_push
    by_hand = { event: "workflow_dispatch" }
    step = cop(*red_batch("a"), bisect_run("c", 3, "success", **by_hand), bisect_run("d", 4, "failure", **by_hand))

    assert_equal([:rerun, commit("d"), 4], [step.action, step.commit, step.run])
  end

  def test_the_newest_run_that_failed_names_the_jobs_to_judge_by
    newer = ci_run("f", 3, "failure", jobs: [job(OTHER, "failure")])
    step = cop(ci_run("a", 1, "success"), ci_run("f", 2, "failure"), newer)

    assert_equal([:bisect, true, false], [step.action, step.reason.include?(OTHER), step.reason.include?(FAILED)])
  end

  # Runs end as canceled after a push replaces them, and say nothing of the
  # failure an older run found.
  def test_a_newer_run_that_was_canceled_does_not_hide_a_red_run
    step = cop(*red_batch("a"), ci_run("f", 3, "cancelled", jobs: []))

    assert_equal([:bisect, commit("c")], [step.action, step.commit])
  end

  # D's second attempt failed FAILED only on its first attempt: OTHER, which
  # passed on the second, is no failure of it.
  def test_a_job_that_failed_on_the_first_attempt_has_not_failed_again
    broken = ci_run("f", 2, "failure", jobs: [job(FAILED, "failure"), job(OTHER, "failure")])
    parent = bisect_run("c", 3, "success", jobs: [job(FAILED, "success"), job(OTHER, "success")])
    second = bisect_run("d", 4, "failure", run_attempt: 2, jobs: [job(FAILED, "failure", 1), job(OTHER, "success", 2)])

    assert_equal(:rerun, cop(ci_run("a", 1, "success"), broken, parent, second).action)
  end

  # C passed FAILED and skipped OTHER, so it has not passed what failed in F.
  def test_a_commit_that_skipped_one_of_the_failed_jobs_has_not_passed_them
    broken = ci_run("f", 2, "failure", jobs: [job(FAILED, "failure"), job(OTHER, "failure")])
    skipped = bisect_run("c", 3, "failure", jobs: [job(FAILED, "success"), job(OTHER, "skipped")])
    step = cop(ci_run("a", 1, "success"), broken, skipped)

    assert_equal([:rerun, commit("c"), 3], [step.action, step.commit, step.run])
  end

  # A run on trunk that was canceled has passed nothing, whatever jobs it ran.
  def test_a_run_that_was_canceled_is_not_green
    step = cop(ci_run("a", 1, "cancelled", jobs: [job(FAILED, "success")]), ci_run("f", 2, "failure"))

    assert_equal([:none, true], [step.action, step.reason.include?("no commit of the last 3 days")])
  end

  def test_a_run_with_no_job_is_not_green
    step = cop(ci_run("a", 1, "success", jobs: []), ci_run("f", 2, "failure"))

    assert_equal([:none, true], [step.action, step.reason.include?("no commit of the last 3 days")])
  end

  # The parent's run is on a branch of the cop's, so trunk has none of it.
  def test_a_parents_run_on_another_branch_says_nothing_of_trunk_to_fast
    parent = fast_run("b", 2, "success", head_branch: "bisect/#{commit('b')}")
    step = cop(fast: [fast_run("a", 1, "success"), parent, fast_failed_again("c", 3)])

    assert_equal([:stuck, true], [step.action, step.reason.include?(commit("b"))])
  end

  # A run that waits for approval has no job yet.
  def test_a_parents_run_that_waits_for_approval_with_no_job_has_not_finished
    waiting = fast_run("b", 2, "action_required", jobs: [])
    step = cop(fast: [fast_run("a", 1, "success"), waiting, fast_failed_again("c", 3)])

    assert_equal(:wait, step.action)
  end

  # A run that is going has no conclusion yet; one that carries the last
  # attempt's is not red either, since the cop reads it again once it ends.
  def test_a_run_that_has_not_completed_is_not_red_whatever_conclusion_it_carries
    step = cop(ci_run("a", 1, "success"), ci_run("f", 2, "failure", status: "in_progress"))

    assert_equal([:none, true], [step.action, step.reason.include?("no run on trunk since")])
  end
end
