# frozen_string_literal: true

require_relative "support/build_cop_case"

# Which conclusions the build cop reads as a failure, and which as a run that
# has not finished (.github/workflows/build-cop.yml). A job that failed or
# timed out failed. A job that was canceled, skipped, or neutral did not, and a
# run that needs a person's approval has not finished.
class BuildCopConclusionTest < Minitest::Test
  include BuildCopCase

  def test_a_job_that_timed_out_failed
    timed_out = ci_run("f", 2, "failure", jobs: [job(FAILED, "timed_out")])
    step = cop(ci_run("a", 1, "success"), timed_out)

    assert_equal([:bisect, commit("c")], [step.action, step.commit])
    assert_includes(step.reason, FAILED)
  end

  def test_a_run_that_timed_out_is_red
    step = cop(ci_run("a", 1, "success"), ci_run("f", 2, "timed_out", jobs: [job(FAILED, "timed_out")]))

    assert_equal([:bisect, commit("c")], [step.action, step.commit])
  end

  # C's run timed out where F's job failed: C failed the job too.
  def test_a_commit_whose_job_timed_out_is_bad
    middle = bisect_run("c", 3, "failure", jobs: [job(FAILED, "timed_out")])
    step = cop(*red_batch("a"), middle)

    assert_equal([:bisect, commit("b")], [step.action, step.commit])
  end

  def test_a_job_that_timed_out_on_its_second_attempt_failed_again
    second = bisect_run("d", 4, "failure", run_attempt: 2, jobs: [job(FAILED, "timed_out", 2)])
    step = cop(*red_batch("a"), bisect_run("c", 3, "success"), second)

    assert_equal([:revert, commit("d")], [step.action, step.commit])
  end

  %w[neutral skipped cancelled].each do |conclusion|
    define_method(:"test_a_job_that_is_#{conclusion}_did_not_fail") do
      step = cop(ci_run("a", 1, "success"), ci_run("f", 2, "failure", jobs: [job(FAILED, conclusion)]))

      assert_equal([:none, true], [step.action, step.reason.include?("no job that failed")])
    end
  end

  # An approval holds the run, as a run in progress is held: nothing is
  # judged by it yet.
  def test_a_run_that_waits_for_approval_has_not_finished
    waiting = bisect_run("c", 3, "action_required", jobs: [job(FAILED, "action_required")])
    step = cop(*red_batch("a"), waiting)

    assert_equal([:wait, true], [step.action, step.reason.include?(commit("c"))])
  end

  def test_a_job_that_waits_for_approval_leaves_its_run_unfinished
    waiting = bisect_run("c", 3, "success", jobs: [job(FAILED, "success"), job(OTHER, "action_required")])
    step = cop(*red_batch("a"), waiting)

    assert_equal([:wait, true], [step.action, step.reason.include?(commit("c"))])
  end

  def test_a_run_on_trunk_that_waits_for_approval_is_not_red_yet
    waiting = ci_run("f", 2, "action_required", jobs: [job(FAILED, "action_required")])

    assert_equal(:none, cop(ci_run("a", 1, "success"), waiting).action)
  end

  def test_a_parent_whose_run_waits_for_approval_is_waited_for
    waiting = bisect_run("e", 5, "action_required", jobs: [job(FAILED, "action_required")])
    step = cop(*red_batch("e"), second_failure("f", 4), waiting)

    assert_equal([:wait, true], [step.action, step.reason.include?(commit("e"))])
  end
end
