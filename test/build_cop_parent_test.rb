# frozen_string_literal: true

require_relative "support/build_cop_case"

# How the build cop vouches for the parent of the commit it would revert
# (.github/workflows/build-cop.yml). A failure that outlasts a rerun, as a rate
# limit does, fails every run alike, so the parent, whose only green run on
# trunk is hours old, is run again on a bisect branch before the commit takes
# the blame.
class BuildCopParentTest < Minitest::Test
  include BuildCopCase

  def test_runs_the_parent_again_before_a_revert_when_only_trunks_old_run_vouches_for_it
    step = cop(*parent_batch)

    assert_equal([:bisect, commit("e")], [step.action, step.commit])
  end

  def test_the_reason_for_running_the_parent_names_the_run_the_job_and_the_parent
    assert_says(cop(*parent_batch), commit("f"), commit("e"), "run 4", FAILED)
  end

  def test_waits_for_the_run_of_the_parent_that_it_started
    step = cop(*parent_batch(bisect_run("e", 5, nil)))

    assert_equal([:wait, true], [step.action, step.reason.include?(commit("e"))])
  end

  def test_reverts_when_the_parent_passes_when_run_again
    step = cop(*parent_batch(bisect_run("e", 5, "success")))

    assert_equal([:revert, commit("f"), 4], [step.action, step.commit, step.run])
  end

  # The parent fails the job too, so the cause is outside the batch: nothing is
  # reverted, and the run that shows it is named.
  def test_reverts_nothing_when_the_parent_fails_the_job_too
    step = cop(*parent_batch(bisect_run("e", 5, "failure", html_url: "https://example.test/runs/5")))

    assert_equal(:stuck, step.action)
    assert_includes(step.reason, "outside the batch")
    assert_includes(step.reason, "https://example.test/runs/5")
  end

  def test_a_run_of_the_parent_without_a_link_is_named_by_its_id
    step = cop(*parent_batch(bisect_run("e", 5, "failure")))

    assert_includes(step.reason, "(5)")
  end

  def test_a_cancelled_run_of_the_parent_is_started_again
    step = cop(*parent_batch(bisect_run("e", 5, "cancelled", jobs: [])))

    assert_equal([:bisect, commit("e")], [step.action, step.commit])
  end

  def test_the_run_of_the_parent_that_does_not_tell_runs_again_once
    untold = bisect_run("e", 5, "failure", jobs: [job(FAILED, "skipped")])

    step = cop(*parent_batch(untold))

    assert_equal([:rerun, commit("e"), 5], [step.action, step.commit, step.run])
  end

  def test_the_run_of_the_parent_that_does_not_tell_on_its_second_attempt_is_a_persons
    untold = bisect_run("e", 5, "failure", run_attempt: 2, jobs: [job(FAILED, "skipped")])

    assert_equal(:stuck, cop(*parent_batch(untold)).action)
  end

  # E is the parent of F, the first bad commit, and passed in trunk's green run
  # before the failure.
  private def parent_batch(*more)
    [*red_batch("e"), second_failure("f", 4), *more]
  end
end
