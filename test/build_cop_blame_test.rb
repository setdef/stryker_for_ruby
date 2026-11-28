# frozen_string_literal: true

require_relative "support/build_cop_case"

# How the build cop blames a commit (.github/workflows/build-cop.yml): the
# first bad commit has its failed jobs run again, so that a flake blames
# nobody, and when they fail again its parent has to pass them in a run since
# trunk went red before it is named to revert.
class BuildCopBlameTest < Minitest::Test
  include BuildCopCase

  def test_runs_the_first_bad_commits_failed_jobs_again_before_it_blames_it
    step = cop(*red_batch("a"), bisect_run("c", 3, "success"), bisect_run("d", 4, "failure"))

    assert_equal([:rerun, commit("d"), 4], [step.action, step.commit, step.run])
  end

  def test_the_reason_for_running_the_jobs_again_names_the_run_the_commit_and_the_jobs
    step = cop(*red_batch("a"), bisect_run("c", 3, "success"), bisect_run("d", 4, "failure"))

    assert_says(step, "run 4 of #{commit('d')}", FAILED, "its parent passed")
  end

  # A batch of one commit after the green one blames it at once, once its run
  # has failed twice.
  def test_a_red_run_right_after_a_green_one_needs_no_bisecting
    step = cop(*red_batch("e"))

    assert_equal([:rerun, commit("f"), 2], [step.action, step.commit, step.run])
  end

  def test_names_the_commit_to_revert_when_its_job_fails_again
    step = cop(*red_batch("a"), bisect_run("c", 3, "success"), second_failure("d", 4))

    assert_equal([:revert, commit("d"), 4], [step.action, step.commit, step.run])
  end

  # D's job failed twice and its parent C passed in a run of C on its bisect
  # branch, which was run after trunk went red: the batch is at fault, and the
  # revert is safe.
  def test_a_revert_names_the_parents_run_that_passed
    step = cop(*red_batch("a"), bisect_run("c", 3, "success"), second_failure("d", 4))

    assert_includes(step.reason, "run 3 of its parent")
  end

  # A second attempt in which only another job failed again is no second
  # failure of the job that turned trunk red.
  def test_a_second_attempt_of_another_job_blames_nobody
    second = bisect_run("d", 4, "failure", run_attempt: 2, jobs: [job(FAILED, "failure"), job(OTHER, "failure", 2)])

    assert_equal(:rerun, cop(*red_batch("a"), bisect_run("c", 3, "success"), second).action)
  end

  # D's job passed when it was run again: a flake, so D is good and the blame
  # moves on to E.
  def test_a_job_that_passes_when_run_again_clears_its_commit
    healed = bisect_run("d", 4, "success", run_attempt: 2, jobs: [job(FAILED, "success", 2)])
    step = cop(*red_batch("a"), bisect_run("c", 3, "success"), healed, bisect_run("e", 5, "failure"))

    assert_equal([:rerun, commit("e")], [step.action, step.commit])
  end
end
