# frozen_string_literal: true

require_relative "support/build_cop_case"

# Where the build cop bisects a red batch (.github/workflows/build-cop.yml): in
# the commits between the newest one that passed the jobs that failed and the
# oldest one that failed them, once no run between them is still going, and
# only after the green run, never at a commit that has a green run itself.
class BuildCopHalveTest < Minitest::Test
  include BuildCopCase

  def test_the_reason_says_which_commit_passed_which_jobs_and_which_failed_them
    both = ci_run("f", 2, "failure", jobs: [job(FAILED, "failure"), job(OTHER, "failure")])
    step = cop(ci_run("a", 1, "success"), both)

    assert_equal(
      "#{commit('a')} passed #{FAILED}, #{OTHER} and #{commit('f')} failed; 4 commits between",
      step.reason
    )
  end

  # B is the commit next to the one that passed.
  def test_it_waits_for_a_run_of_the_commit_after_the_one_that_passed
    step = cop(*red_batch("a"), bisect_run("b", 3, nil))

    assert_equal([:wait, true], [step.action, step.reason.include?(commit("b"))])
  end

  # E is the commit next to the one that failed.
  def test_it_waits_for_a_run_of_the_commit_before_the_one_that_failed
    step = cop(*red_batch("a"), bisect_run("e", 3, nil))

    assert_equal([:wait, true], [step.action, step.reason.include?(commit("e"))])
  end

  # A's green run is the one that bounds the batch. A run of A that failed, as
  # one a person started by hand may have, is no part of it.
  def test_a_red_run_of_the_commit_that_passed_is_not_judged
    by_hand = ci_run("a", 2, "failure", event: "workflow_dispatch")
    step = cop(ci_run("a", 1, "success"), by_hand, ci_run("f", 3, "failure"))

    assert_equal([:bisect, commit("c")], [step.action, step.commit])
  end
end
