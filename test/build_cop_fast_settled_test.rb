# frozen_string_literal: true

require_relative "support/build_cop_case"

# When a red run of fast.yml stops blocking the build cop, which runs it
# ignores, and how its step ranks beside the step for ci.yml
# (.github/workflows/build-cop.yml). Like a red run of ci.yml, a red run of
# Fast is settled once the commit it names has been reverted on trunk, or a
# newer run on trunk passed.
class BuildCopFastSettledTest < Minitest::Test
  include BuildCopCase

  def test_nothing_is_done_when_no_commit_has_a_green_run
    step = cop(fast: [fast_run("c", 2, "failure")])

    assert_equal(:none, step.action)
    assert_includes(step.reason, "green")
  end

  def test_nothing_is_done_when_no_run_is_red
    step = cop(fast: [fast_run("b", 1, "success"), fast_run("c", 2, "success")])

    assert_equal(:none, step.action)
  end

  def test_a_run_that_is_running_again_blames_nobody_yet
    step = cop(fast: [fast_run("b", 1, "success"), fast_run("c", 2, nil, run_attempt: 2)])

    assert_equal(:none, step.action)
  end

  def test_a_red_run_is_settled_when_a_newer_commit_reverts_its_commit
    step = cop(fast: [fast_run("a", 1, "success"), fast_failed_again("c", 2)], reverts: [[commit("d"), commit("c")]])

    assert_equal(:none, step.action)
  end

  def test_a_revert_older_than_the_red_run_does_not_settle_it
    fast = [fast_run("a", 1, "success"), fast_run("c", 2, "success"), fast_failed_again("d", 3)]
    step = cop(fast:, reverts: [[commit("c"), commit("b")]])

    assert_equal([:revert, commit("d")], [step.action, step.commit])
  end

  def test_a_revert_that_was_reverted_settles_nothing
    reverts = [[commit("d"), commit("c")], [commit("e"), commit("d")]]
    step = cop(fast: [fast_run("b", 1, "success"), fast_failed_again("c", 2)], reverts:)

    assert_equal([:revert, commit("c")], [step.action, step.commit])
  end

  # A newer run passed, so C's failure did not outlast it.
  def test_a_red_run_is_settled_when_a_newer_run_passed
    step = cop(fast: [fast_run("a", 1, "success"), fast_failed_again("c", 2), fast_run("e", 3, "success")])

    assert_equal(:none, step.action)
  end

  # The run on a bisect branch is no run of trunk, and is not read as one.
  def test_a_run_on_another_branch_says_nothing_of_trunk
    bisecting = fast_run("c", 2, "failure", head_branch: "bisect/#{commit('c')}")
    step = cop(fast: [fast_run("b", 1, "success"), bisecting])

    assert_equal(:none, step.action)
  end

  def test_a_run_of_a_pull_request_says_nothing_of_trunk
    step = cop(fast: [fast_run("b", 1, "success"), fast_run("c", 2, "failure", event: "pull_request")])

    assert_equal(:none, step.action)
  end

  # The step for a red run of Fast comes before ci.yml's, which reads the same
  # commit as one of its batch.
  def test_a_step_for_fast_comes_before_the_step_for_ci
    step = cop(*red_batch("a"), fast: [fast_run("b", 1, "success"), fast_run("c", 2, "failure")])

    assert_equal([:rerun, commit("c")], [step.action, step.commit])
  end

  def test_a_step_for_ci_comes_when_fast_has_nothing_to_do
    step = cop(*red_batch("a"), fast: [fast_run("b", 1, "success")])

    assert_equal([:bisect, commit("c")], [step.action, step.commit])
  end

  # Fast waits for the parent, and ci.yml has nothing to say: the cop says why
  # it waits, instead of that no run is red.
  def test_what_fast_waits_for_is_said_when_ci_has_nothing_to_do
    fast = [fast_run("a", 1, "success"), fast_run("b", 2, nil), fast_failed_again("c", 3)]
    step = cop(ci_run("f", 1, "success"), fast:)

    assert_equal(:wait, step.action)
  end

  def test_ci_says_why_when_neither_has_anything_to_do
    step = cop(ci_run("f", 1, "success"), fast: [fast_run("b", 1, "success")])

    assert_equal(:none, step.action)
    assert_includes(step.reason, "no run on trunk since")
  end
end
