# frozen_string_literal: true

require_relative "support/build_cop_script_case"

# What .github/scripts/build-cop.sh gives the task and says of its step: trunk's
# newest 300 first-parent commits, from the origin, and the reverts among
# them; the step as lines for GITHUB_OUTPUT and a line for the job's summary;
# and no step taken when the task fails.
class BuildCopInputScriptTest < Minitest::Test
  include BuildCopScriptCase

  LIMIT = 300
  private_constant(:LIMIT)

  def test_it_lists_trunks_first_parent_commits_newest_first
    base = git(@work, "rev-parse", "HEAD").strip
    merged = merge_of_a_branch_with_a_revert
    cop(merged, "wait")

    assert_equal([merged, base], commits_seen.lines(chomp: true).values_at(0, -1))
  end

  def test_a_commit_of_a_merged_branch_is_no_commit_of_trunk
    side = merge_of_a_branch_with_a_revert.then { git(@work, "rev-parse", "side").strip }
    cop(origin_head, "wait")

    refute_includes(commits_seen, side)
  end

  def test_a_revert_on_a_merged_branch_is_no_revert_of_trunk
    cop(merge_of_a_branch_with_a_revert, "wait")

    assert_equal("", reverts_seen)
  end

  # The clone may be behind the origin, as the cop's checkout is by the time
  # the run starts.
  def test_it_reads_trunk_from_the_origin
    tip = pushed_commit("revert: newer\n\nThis reverts commit #{'a' * 40}.")
    git(@work, "reset", "--quiet", "--hard", "HEAD~1")
    cop(tip, "wait")

    assert_equal([tip, "#{tip} #{'a' * 40}\n"], [commits_seen.lines.first.chomp, reverts_seen])
  end

  # Commits that say nothing of reverts, so that the script's search of their
  # messages, which asks git once for each revert it finds, has nothing to do.
  def test_it_lists_the_newest_300_commits_of_trunk
    cop(trunk_of_commits(LIMIT + 5), "wait")

    assert_equal(LIMIT, commits_seen.lines.size)
  end

  def test_the_step_is_lines_appended_to_github_output
    output = File.join(@dir, "output.txt")
    File.write(output, "earlier=1\n")
    bad = pushed_commit("feat: bad")
    cop(bad, "wait", GITHUB_OUTPUT: output)

    assert_equal("earlier=1\naction=wait\ncommit=#{bad}\nrun=1\nreason=setdef/stryker_for_ruby\n", File.read(output))
  end

  def test_the_step_is_a_line_of_the_summary
    summary = File.join(@dir, "summary.txt")
    bad = pushed_commit("feat: bad")
    cop(bad, "wait", GITHUB_STEP_SUMMARY: summary)

    assert_equal("wait #{bad}: setdef/stryker_for_ruby\n", File.read(summary))
  end

  # A step with no commit says no commit, and no space where it would be.
  def test_a_step_with_no_commit_is_a_line_without_one
    summary = File.join(@dir, "summary.txt")
    git(@work, "push", "--quiet", "origin", "trunk")
    cop("", "wait", GITHUB_STEP_SUMMARY: summary)

    assert_equal("wait: setdef/stryker_for_ruby\n", File.read(summary))
  end

  # The task is Ruby, and a failure of its own ends the run before any step.
  def test_a_task_that_fails_ends_the_run_with_its_own_message
    git(@work, "push", "--quiet", "origin", "trunk")
    out = failing_cop_with_task("raise 'the task broke'\n", BUILD_COP_REVERT: "true")

    assert_includes(out, "the task broke")
    refute_includes(out, "said nothing it knows")
  end

  private def merge_of_a_branch_with_a_revert
    git(@work, "checkout", "--quiet", "-b", "side")
    commit("revert: side\n\nThis reverts commit #{'a' * 40}.", "side.txt", "side\n")
    git(@work, "checkout", "--quiet", "trunk")
    commit("feat: on trunk", "trunk.txt", "trunk\n")
    git(@work, "merge", "--quiet", "--no-ff", "-m", "merge side", "side")
    git(@work, "push", "--quiet", "origin", "trunk")
    git(@work, "rev-parse", "HEAD").strip
  end

  # +count+ commits on top of trunk, made in one process: a commit apiece with
  # git commit would take seconds.
  private def trunk_of_commits(count)
    head = git(@work, "rev-parse", "HEAD").strip
    stream = Array.new(count) { |index| commit_in_stream(index, head) }
    env = variables(GIT_ENV)
    out, status = Open3.capture2e(env, "git", "fast-import", "--quiet", stdin_data: stream.join, chdir: @work)
    flunk(out) unless status.success?

    git(@work, "reset", "--quiet", "--hard", "trunk")
    git(@work, "push", "--quiet", "origin", "trunk")
    origin_head
  end

  private def commit_in_stream(index, head)
    message = "feat: n#{index}\n"
    parent = index.zero? ? head : ":#{index}"
    "commit refs/heads/trunk\nmark :#{index + 1}\ncommitter t <t@example.com> #{index} +0000\n" \
      "data #{message.bytesize}\n#{message}from #{parent}\n\n"
  end
end
