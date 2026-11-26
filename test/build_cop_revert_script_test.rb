# frozen_string_literal: true

require_relative "support/build_cop_script_case"

# The revert and rerun steps of .github/scripts/build-cop.sh: it reverts a
# commit on trunk only when asked to, never reverts a revert, and runs the
# failed jobs of a run again.
class BuildCopRevertScriptTest < Minitest::Test
  include BuildCopScriptCase

  def test_a_commit_reverted_already_is_left_alone_however_long_trunks_history
    bad = pushed_commit("feat: bad")
    git(@work, "revert", "--no-edit", bad)
    # More log than a pipe holds, below the revert, so that a reader that stops
    # at the match leaves the log writing into a closed pipe.
    8.times { |index| commit("filler #{index} #{'x' * 16_000}", "f#{index}.txt", "x\n") }
    git(@work, "push", "--quiet", "origin", "trunk")

    assert_match(/reverted on trunk already/, cop(bad, "revert", BUILD_COP_REVERT: "true"))
  end

  def test_a_commit_reverted_already_is_reverted_no_more
    bad = pushed_commit("feat: bad")
    git(@work, "revert", "--no-edit", bad)
    git(@work, "push", "--quiet", "origin", "trunk")
    before = origin_head
    cop(bad, "revert", BUILD_COP_REVERT: "true")

    assert_equal(before, origin_head)
    refute_path_exists(File.join(@dir, "gh.log"))
  end

  def test_it_reverts_nothing_until_asked_to
    bad = pushed_commit("feat: bad")
    before = origin_head
    out = cop(bad, "revert")

    assert_match(/BUILD_COP_REVERT is not true/, out)
    assert_equal(before, origin_head)
  end

  def test_it_reverts_the_commit_when_asked_to
    bad = pushed_commit("feat: bad")
    cop(bad, "revert", BUILD_COP_REVERT: "true")
    message = git(@dir, "--git-dir", @origin, "log", "-1", "--format=%B", "trunk")

    assert_match(/\Arevert: feat: bad\n/, message)
    assert_includes(message, "This reverts commit #{bad}.")
    refute_includes(git(@dir, "--git-dir", @origin, "ls-tree", "--name-only", "trunk"), "bad.txt")
  end

  def test_it_starts_a_run_on_trunk_to_judge_the_revert
    cop(pushed_commit("feat: bad"), "revert", BUILD_COP_REVERT: "true")

    assert_includes(gh_log, "workflow run ci.yml --ref trunk")
  end

  def test_a_revert_is_a_persons_to_revert
    subjects = ["revert: feat: bad", "revert(loader): feat: bad", "revert!: feat: bad", 'Revert "feat: bad"']
    subjects.each_with_index do |subject, index|
      bad = pushed_commit(subject, "s#{index}.txt")
      before = origin_head

      assert_match(/a person's to revert/, cop(bad, "revert", BUILD_COP_REVERT: "true"), subject)
      assert_equal(before, origin_head, subject)
    end
  end

  # GitHub refuses to run again the jobs of a run that has no failed job, or is
  # running again already: that is a warning, not a red run of the cop.
  def test_a_rerun_that_github_refuses_is_a_warning
    File.write(File.join(@dir, "gh.fail_rerun"), "")

    assert_match(/::warning::.*run 1/, cop(pushed_commit("feat: x"), "rerun"))
  end

  def test_it_runs_the_failed_jobs_again
    cop(pushed_commit("feat: x"), "rerun")

    assert_includes(gh_log, "run rerun 1 --failed")
  end
end
