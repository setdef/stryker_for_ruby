# frozen_string_literal: true

require_relative "support/build_cop_case"

# How the build cop bisects a red batch (.github/workflows/build-cop.yml): it
# works on the oldest red run on trunk after its newest green one, and judges
# each commit between them by the jobs that failed in the red run alone.
class BuildCopBisectTest < Minitest::Test
  include BuildCopCase

  def test_nothing_to_do_when_the_newest_finished_run_on_trunk_is_green
    step = cop(ci_run("a", 1, "success"), ci_run("f", 2, "success"))

    assert_equal(:none, step.action)
    assert_includes(step.reason, "is red")
  end

  def test_bisects_a_red_batch_after_a_green_run_at_its_middle
    step = cop(*red_batch("a"))

    assert_equal([:bisect, commit("c")], [step.action, step.commit])
  end

  def test_the_reason_names_the_failed_job_and_the_commits_left
    step = cop(*red_batch("a"))

    assert_includes(step.reason, FAILED)
    assert_includes(step.reason, "4 commits between")
  end

  # Runs a newer push replaced while they waited ran no job, and tell nothing.
  def test_a_cancelled_run_tells_nothing
    step = cop(*red_batch("a"), ci_run("c", 3, "cancelled", jobs: []))

    assert_equal([:bisect, commit("c")], [step.action, step.commit])
  end

  def test_waits_while_a_bisecting_run_has_not_finished
    step = cop(*red_batch("a"), bisect_run("c", 3, nil))

    assert_equal([:wait, true], [step.action, step.reason.include?(commit("c"))])
  end

  # C passed the job that failed, and E failed it, so D is next; other jobs of
  # C's run that failed say nothing about this failure.
  def test_narrows_by_the_jobs_that_failed_in_the_red_run_alone
    middle = bisect_run("c", 3, "failure", jobs: [job(FAILED, "success"), job(OTHER, "failure")])
    step = cop(*red_batch("a"), middle, bisect_run("e", 4, "failure"))

    assert_equal([:bisect, commit("d")], [step.action, step.commit])
  end

  # F's red run has been run again on a bisect branch, and that run has not
  # finished.
  def test_waits_while_the_red_commit_runs_again
    step = cop(*red_batch("a"), bisect_run("f", 3, nil))

    assert_equal([:wait, true], [step.action, step.reason.include?(commit("f"))])
  end

  # A run that is red only for jobs cancelled, such as one no runner took, is
  # not the cop's: no commit failed it.
  def test_nothing_to_do_for_a_run_red_only_for_cancelled_jobs
    step = cop(ci_run("a", 1, "success"), ci_run("f", 2, "failure", jobs: [job(FAILED, "cancelled")]))

    assert_equal([:none, true], [step.action, step.reason.include?("no job that failed")])
  end

  def test_nothing_to_do_without_a_green_run_on_trunk
    step = cop(ci_run("f", 2, "failure"), bisect_run("a", 1, "success"))

    assert_equal(:none, step.action)
  end

  # Pull requests' runs check out a merge, not the commit, and count for
  # nothing.
  def test_a_pull_requests_run_counts_for_nothing
    step = cop(*red_batch("a"), ci_run("c", 3, "success", event: "pull_request"))

    assert_equal(commit("c"), step.commit)
  end

  # A run with a job skipped says nothing of the jobs a full run runs, and the
  # batch it follows may hold an earlier red.
  def test_a_run_that_skipped_jobs_is_not_a_green_run
    short = ci_run("e", 4, "success", jobs: [job(OTHER, "success"), job(FAILED, "skipped")])
    step = cop(ci_run("a", 1, "success"), short, ci_run("f", 2, "failure"))

    assert_equal([:bisect, commit("c")], [step.action, step.commit])
  end

  # F's own run passing when run again makes F the newest green run.
  def test_a_red_run_that_passes_when_run_again_leaves_nothing_to_do
    again = ci_run("f", 2, "success", run_attempt: 2, jobs: [job(FAILED, "success", 2)])

    assert_equal(:none, cop(ci_run("a", 1, "success"), again).action)
  end

  def test_does_nothing_while_the_red_run_runs_again
    assert_equal(:none, cop(ci_run("a", 1, "success"), ci_run("f", 2, nil, run_attempt: 2)).action)
  end
end
