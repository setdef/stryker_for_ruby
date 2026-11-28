# frozen_string_literal: true

require_relative "support/build_cop_case"

# How the build cop follows fast.yml (.github/workflows/build-cop.yml). A run
# of Fast on trunk names exactly one commit, so a red one needs no bisecting:
# its failed jobs run again once, and when they fail again and the run of the
# commit's parent passed, the commit is the one to revert. The parent is
# judged first.
class BuildCopFastTest < Minitest::Test
  include BuildCopCase

  def test_a_red_run_runs_its_failed_jobs_again_once
    step = cop(fast: [fast_run("b", 1, "success"), fast_run("c", 2, "failure")])

    assert_equal([:rerun, commit("c"), 102], [step.action, step.commit, step.run])
    assert_includes(step.reason, FAST_FAILED)
  end

  # F, the newest commit, is the one whose run is red.
  def test_the_newest_commits_red_run_is_judged
    step = cop(fast: [fast_run("e", 1, "success"), fast_run("f", 2, "failure")])

    assert_equal([:rerun, commit("f"), 102], [step.action, step.commit, step.run])
  end

  # B has a green run and an older red one: the red run is not after the green.
  def test_a_red_run_of_the_commit_that_has_a_green_run_is_not_judged
    red = fast_run("b", 2, "failure", event: "workflow_dispatch")
    step = cop(fast: [fast_run("b", 1, "success"), red, fast_run("c", 3, "failure")])

    assert_equal([:rerun, commit("c")], [step.action, step.commit])
  end

  def test_jobs_that_fail_again_blame_the_commit_when_its_parent_passed
    step = cop(fast: [fast_run("b", 1, "success"), fast_failed_again("c", 2)])

    assert_equal([:revert, commit("c"), 102], [step.action, step.commit, step.run])
    assert_includes(step.reason, "the run of its parent passed")
  end

  def test_a_run_that_timed_out_is_red
    timed_out = fast_run("c", 2, "timed_out", jobs: [job(FAST_FAILED, "timed_out")])
    step = cop(fast: [fast_run("b", 1, "success"), timed_out])

    assert_equal([:rerun, commit("c")], [step.action, step.commit])
    assert_includes(step.reason, FAST_FAILED)
  end

  def test_a_job_that_timed_out_on_its_second_attempt_failed_again
    second = fast_run("c", 2, "failure", run_attempt: 2, jobs: [job(FAST_FAILED, "timed_out", 2)])
    step = cop(fast: [fast_run("b", 1, "success"), second])

    assert_equal([:revert, commit("c")], [step.action, step.commit])
  end

  def test_nothing_is_reverted_while_its_parents_run_has_not_finished
    step = cop(fast: [fast_run("a", 1, "success"), fast_run("b", 2, nil), fast_failed_again("c", 3)])

    assert_equal(:wait, step.action)
    assert_includes(step.reason, commit("b"))
  end

  # B is the oldest red run, so the cop judges it first, and C waits.
  def test_the_parent_is_judged_first_when_its_run_failed
    step = cop(fast: [fast_run("a", 1, "success"), fast_run("b", 2, "failure"), fast_failed_again("c", 3)])

    assert_equal([:rerun, commit("b")], [step.action, step.commit])
  end

  # B's red run is settled by a revert, and C's red run waits for a green run
  # of a commit after it: B's failure may be what failed C.
  def test_nothing_is_done_for_a_run_whose_parents_run_failed
    reverts = [[commit("e"), commit("b")]]
    fast = [fast_run("a", 1, "success"), fast_run("b", 2, "failure"), fast_failed_again("c", 3)]
    step = cop(fast:, reverts:)

    assert_equal(:wait, step.action)
    assert_includes(step.reason, "failed")
  end

  def test_a_parent_with_no_run_is_left_for_a_person
    step = cop(fast: [fast_run("a", 1, "success"), fast_failed_again("c", 3)])

    assert_equal(:stuck, step.action)
    assert_includes(step.reason, commit("b"))
  end

  def test_a_parent_whose_run_was_skipped_is_left_for_a_person
    skipped = fast_run("b", 2, "skipped", jobs: [job(FAST_GATE, "skipped")])
    step = cop(fast: [fast_run("a", 1, "success"), skipped, fast_failed_again("c", 3)])

    assert_equal(:stuck, step.action)
  end

  def test_a_parent_that_waits_for_approval_has_not_finished
    waiting = fast_run("b", 2, "action_required", jobs: [job(FAST_GATE, "action_required")])
    step = cop(fast: [fast_run("a", 1, "success"), waiting, fast_failed_again("c", 3)])

    assert_equal(:wait, step.action)
  end

  # A run that failed without a failed job has no job to run again.
  def test_a_red_run_with_no_job_that_failed_is_left_for_a_person
    canceled = fast_run("c", 2, "failure", jobs: [job(FAST_FAILED, "cancelled")])
    step = cop(fast: [fast_run("b", 1, "success"), canceled])

    assert_equal(:stuck, step.action)
    assert_says(step, "run 102", "no job that failed")
  end
end
