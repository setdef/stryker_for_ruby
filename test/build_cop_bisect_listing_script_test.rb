# frozen_string_literal: true

require_relative "support/build_cop_script_case"

# How .github/scripts/build-cop.sh asks GitHub for the run of ci.yml that it
# started on a bisect branch, and what it does with a branch that is there
# already.
class BuildCopBisectListingScriptTest < Minitest::Test
  include BuildCopScriptCase

  LISTED = "run list --workflow ci.yml --branch bisect/%<commit>s --event workflow_dispatch --json databaseId"
  private_constant(:LISTED)

  # GitHub lists a run only minutes after it starts one, so the script waits for
  # it: thirty tries, ten seconds apart, and no longer.
  def test_it_asks_thirty_times_ten_seconds_apart_for_the_run_it_started
    cop(bisect_commit(WITH_DISPATCH), "bisect")

    assert_equal(30, gh_log.lines.count { |line| line.include?("databaseId,conclusion") })
    assert_equal(["10"] * 30, sleeps)
  end

  def test_it_asks_for_the_runs_of_ci_started_by_hand_on_that_branch_that_were_not_cancelled
    bad = bisect_commit(WITH_DISPATCH)
    cop_bisecting(bad)
    listing = "#{format(LISTED, commit: bad)},conclusion --jq " \
      '[.[] | select(.conclusion != "cancelled") | .databaseId] | first // empty'

    assert_includes(gh_log, listing)
  end

  def test_it_asks_how_many_runs_of_ci_started_by_hand_a_branch_that_is_there_has
    bad = bisect_commit(WITH_DISPATCH)
    git(@work, "push", "--quiet", "origin", "#{bad}:refs/heads/bisect/#{bad}")
    cop_bisecting(bad)

    assert_includes(gh_log, "#{format(LISTED, commit: bad)} --jq length")
  end

  # HEAD of the clone is at a later commit than the one to bisect.
  def test_the_branch_is_made_at_the_commit_and_not_at_the_clones_head
    old = bisect_commit(WITH_DISPATCH)
    pushed_commit("feat: later")
    cop_bisecting(old)

    assert_equal(old, git(@dir, "--git-dir", @origin, "rev-parse", "bisect/#{old}").strip)
  end

  # A tag of the same name is no branch that was asked for.
  def test_a_tag_named_like_the_branch_is_no_branch
    bad = bisect_commit(WITH_DISPATCH)
    git(@work, "tag", "bisect/#{bad}", bad)
    git(@work, "push", "--quiet", "origin", "refs/tags/bisect/#{bad}")
    cop_bisecting(bad)

    assert_includes(origin_branches, "bisect/#{bad}")
    assert_includes(gh_log, "workflow run ci.yml --ref bisect/#{bad}")
  end

  def test_it_says_in_the_summary_which_run_it_started
    summary = File.join(@dir, "summary.txt")
    bad = bisect_commit(WITH_DISPATCH)
    File.write(File.join(@dir, "gh.live"), "4242\n")
    cop_bisecting(bad, GITHUB_STEP_SUMMARY: summary)

    assert_includes(File.read(summary), "Started 4242 of ci.yml on bisect/#{bad}.\n")
  end

  def test_a_branch_whose_runs_were_all_cancelled_is_made_again
    bad = bisect_commit(WITH_DISPATCH)
    git(@work, "push", "--quiet", "origin", "#{bad}:refs/heads/bisect/#{bad}")
    File.write(File.join(@dir, "gh.any"), "1\n")
    pushes = recording_pushes
    cop_bisecting(bad)

    assert_equal(%w[delete create], File.readlines(pushes, chomp: true))
  end

  def test_it_says_in_the_summary_that_the_run_is_not_listed_yet
    summary = File.join(@dir, "summary.txt")
    bad = bisect_commit(WITH_DISPATCH)
    git(@work, "push", "--quiet", "origin", "#{bad}:refs/heads/bisect/#{bad}")
    cop_bisecting(bad, GITHUB_STEP_SUMMARY: summary)

    assert_match(/is not listed yet; not starting it again\.$/, File.read(summary))
  end

  # Has the origin write down whether each push to a branch deletes it or
  # creates it, and returns the file it writes them in.
  private def recording_pushes
    path = File.join(@dir, "pushes")
    File.write(File.join(@origin, "hooks", "pre-receive"), <<~SH, perm: 0o755)
      #!/bin/sh
      while read old new ref; do
        case "$new" in
        0*) echo delete >>"#{path}" ;;
        *) echo create >>"#{path}" ;;
        esac
      done
    SH
    path
  end
end
