# frozen_string_literal: true

require_relative "support/build_cop_case"

# How the build cop treats the run of a commit between the last green one and
# the first red one that finished without passing or failing the job that
# turned trunk red, as when no runner took it or a job it needs failed: its
# failed jobs run again once, and it is then left for a person
# (.github/workflows/build-cop.yml).
class BuildCopUnsettledTest < Minitest::Test
  include BuildCopCase

  def test_a_run_that_did_not_run_the_job_runs_again_once
    step = cop(*red_batch("a"), bisect_run("c", 3, "failure", jobs: [job(FAILED, "skipped")]))

    assert_equal([:rerun, commit("c"), 3], [step.action, step.commit, step.run])
  end

  def test_the_rerun_says_which_run_and_job_was_not_told
    step = cop(*red_batch("a"), bisect_run("c", 3, "failure", jobs: [job(FAILED, "skipped")]))

    assert_says(step, "run 3", FAILED, "its failed jobs run again")
  end

  def test_a_run_that_did_not_run_the_job_on_its_second_attempt_is_left_for_a_person
    step = cop(*red_batch("a"), bisect_run("c", 3, "failure", run_attempt: 2, jobs: [job(FAILED, "skipped")]))

    assert_equal([:stuck, true], [step.action, step.reason.include?("run 3")])
  end

  # A run that finished green has nothing to run again: GitHub refuses to run
  # the failed jobs of a run that has none.
  def test_a_green_run_without_the_job_is_left_for_a_person
    step = cop(*red_batch("a"), bisect_run("c", 3, "success", jobs: [job(OTHER, "success")]))

    assert_equal([:stuck, true], [step.action, step.reason.include?("run 3")])
  end

  # A rerun or a revert changes something, and the others only say.
  def test_a_step_acts_only_when_it_runs_a_job_again_or_reverts
    steps = %i[none wait bisect rerun revert stuck].map { |action| BuildCopStep.of(action, "why") }

    assert_equal(%i[rerun revert], steps.filter_map { |step| step.action if step.acts? })
  end

  def test_a_step_is_lines_for_github_output
    step = BuildCopStep.of(:revert, "why", commit: "abc", run: 4)

    assert_equal("action=revert\ncommit=abc\nrun=4\nreason=why\n", step.to_output)
  end
end
