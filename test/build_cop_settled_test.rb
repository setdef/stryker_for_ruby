# frozen_string_literal: true

require_relative "support/build_cop_case"

# When a red run on trunk stops blocking the build cop
# (.github/workflows/build-cop.yml): once the commit it blamed has been
# reverted on trunk, or a newer run on trunk passed. The cop judges the oldest
# red run that is not settled. A commit that a newer commit has reverted, among
# the commits the red run covers, stands for the commit that was blamed.
class BuildCopSettledTest < Minitest::Test
  include BuildCopCase

  # E's run is red, and F reverts D, one of the commits E's run covers.
  def test_a_red_run_is_settled_when_a_newer_commit_reverts_a_commit_it_covers
    step = cop(*red_at_e, reverts: [[commit("f"), commit("d")]])

    assert_equal(:none, step.action)
    assert_includes(step.reason, "settled")
  end

  # C's red run is settled by D, which reverts B, and E's run, which failed
  # another job, is judged by its own batch.
  def test_the_oldest_red_run_that_is_not_settled_is_judged
    step = cop(*second_break, reverts: [[commit("d"), commit("b")]])

    assert_equal([:bisect, commit("d")], [step.action, step.commit])
    assert_includes(step.reason, OTHER)
  end

  def test_without_a_revert_the_oldest_red_run_is_judged
    step = cop(*second_break)

    assert_equal([:bisect, commit("b")], [step.action, step.commit])
    assert_includes(step.reason, FAILED)
  end

  # C reverts B before E's run, which already holds the revert.
  def test_a_revert_older_than_the_red_run_does_not_settle_it
    step = cop(*red_at_e, reverts: [[commit("c"), commit("b")]])

    assert_equal([:bisect, commit("c")], [step.action, step.commit])
  end

  # E reverts D, but E's own run is the red one: a revert that is the red run's
  # own commit is not a newer one.
  def test_a_revert_that_is_the_red_runs_own_commit_does_not_settle_it
    step = cop(*red_at_e, reverts: [[commit("e"), commit("d")]])

    assert_equal([:bisect, commit("c")], [step.action, step.commit])
  end

  # A is the commit the run before the batch passed.
  def test_a_revert_of_a_commit_before_the_batch_does_not_settle_the_red_run
    step = cop(*red_at_e, reverts: [[commit("f"), commit("a")]])

    assert_equal([:bisect, commit("c")], [step.action, step.commit])
  end

  # F reverts E, and brings C back; E settles nothing.
  def test_a_revert_that_was_reverted_settles_nothing
    reverts = [[commit("e"), commit("c")], [commit("f"), commit("e")]]
    step = cop(ci_run("a", 1, "success"), ci_run("d", 2, "failure"), reverts:)

    assert_equal([:bisect, commit("b")], [step.action, step.commit])
  end

  # D, older than E's run, reverts C first, and F, newer, reverts it again.
  def test_a_commit_reverted_again_is_settled_by_the_newest_revert
    reverts = [[commit("d"), commit("c")], [commit("f"), commit("c")]]

    assert_equal(:none, cop(*red_at_e, reverts:).action)
  end

  # The cop reads only trunk's newest commits, but the reverts it is given may
  # reach further back (git log --max-count counts the commits that match its
  # --grep, not those it walks). A revert older than every commit read can only
  # revert one older still, so it settles nothing here.
  def test_a_revert_older_than_every_commit_read_settles_nothing
    step = cop(*red_at_e, reverts: [["9" * 40, "8" * 40]])

    assert_equal([:bisect, commit("c")], [step.action, step.commit])
  end

  # Even when it reverts a commit that is among those read.
  def test_a_revert_older_than_every_commit_read_of_a_commit_read_settles_nothing
    step = cop(*red_at_e, reverts: [["9" * 40, commit("d")]])

    assert_equal([:bisect, commit("c")], [step.action, step.commit])
  end

  # The same revert does not hide one that settles the red run.
  def test_a_revert_older_than_every_commit_read_leaves_the_others_to_settle
    reverts = [[commit("f"), commit("d")], ["9" * 40, "8" * 40]]

    assert_equal(:none, cop(*red_at_e, reverts:).action)
  end

  def test_a_red_run_older_than_a_newer_green_one_is_settled
    step = cop(ci_run("a", 1, "success"), ci_run("c", 2, "failure"), ci_run("e", 3, "success"))

    assert_equal(:none, step.action)
    assert_includes(step.reason, "no run on trunk since #{commit('e')}")
  end

  # A passes and E is red.
  private def red_at_e
    [ci_run("a", 1, "success"), ci_run("e", 2, "failure")]
  end

  # A passes; C is red on FAILED, and E is red on OTHER while C passed OTHER.
  private def second_break
    broken = ci_run("c", 2, "failure", jobs: [job(FAILED, "failure"), job(OTHER, "success")])
    again = ci_run("e", 3, "failure", jobs: [job(FAILED, "success"), job(OTHER, "failure")])
    [ci_run("a", 1, "success"), broken, again]
  end
end
