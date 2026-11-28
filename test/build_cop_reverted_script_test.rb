# frozen_string_literal: true

require_relative "support/build_cop_script_case"

# How .github/scripts/build-cop.sh tells that trunk has reverted a commit
# already, and what it says and does when it reverts one itself.
class BuildCopRevertedScriptTest < Minitest::Test
  include BuildCopScriptCase

  REVERT = { BUILD_COP_REVERT: "true" }.freeze
  private_constant(:REVERT)

  def test_it_names_the_newest_revert_when_there_are_several
    bad = pushed_commit("feat: bad")
    pushed_commit("revert: feat: bad\n\nThis reverts commit #{bad}.", "first.txt", "1\n")
    newest = pushed_commit("revert: feat: bad, again\n\nThis reverts commit #{bad}.", "second.txt", "2\n")

    assert_includes(cop(bad, "revert", REVERT), "already as #{newest};")
  end

  def test_a_line_that_only_quotes_a_revert_is_no_revert
    bad = pushed_commit("feat: bad")
    pushed_commit("docs: quote\n\nNot a revert: This reverts commit #{bad}.", "quote.txt", "quote\n")
    cop(bad, "revert", REVERT)

    assert_match(/\Arevert: feat: bad\n/, trunks_message)
  end

  def test_the_revert_of_another_commit_is_no_revert_of_this_one
    other = pushed_commit("feat: other", "other.txt", "other\n")
    git(@work, "revert", "--no-edit", other)
    bad = pushed_commit("feat: bad")
    cop(bad, "revert", REVERT)

    assert_match(/\Arevert: feat: bad\n/, trunks_message)
  end

  # The clone is behind the origin, as the cop's checkout is by the time the
  # run starts, and the first look for a revert is at the origin's trunk.
  def test_it_looks_for_the_revert_on_trunk_at_the_origin
    bad = pushed_commit("feat: bad")
    git(@work, "revert", "--no-edit", bad)
    git(@work, "push", "--quiet", "origin", "trunk")
    git(@work, "reset", "--quiet", "--hard", bad)
    summary = File.join(@dir, "summary.txt")
    out = cop(bad, "revert", REVERT.merge(GITHUB_STEP_SUMMARY: summary))

    assert_match(/already as #{origin_head}; trunk's next green run ends this\.$/, out)
    assert_match(/already as #{origin_head}; trunk's next green run ends this\.$/, File.read(summary))
    refute_includes(out, "landed first")
  end

  # HEAD of the clone is at a later commit than the one that turned trunk red.
  def test_the_revert_is_titled_as_the_commit_it_reverts_and_not_as_the_clones_head
    bad = pushed_commit("feat: bad")
    pushed_commit("feat: later", "later.txt", "later\n")
    cop(bad, "revert", REVERT)

    assert_match(/\Arevert: feat: bad\n/, trunks_message)
  end

  def test_the_revert_says_which_workflow_found_it
    cop(pushed_commit("feat: bad"), "revert", REVERT)

    assert_includes(
      trunks_message,
      "setdef/stryker_for_ruby\n(.github/workflows/build-cop.yml). Land it again with the fix."
    )
  end

  def test_the_revert_says_where_it_landed_on_trunk
    bad = pushed_commit("feat: bad")
    out = cop(bad, "revert", REVERT)

    assert_includes(out, "Reverted #{bad} on trunk as #{origin_head}.\n")
    refute_includes(out, "already")
  end

  def test_the_revert_is_a_line_of_the_summary
    summary = File.join(@dir, "summary.txt")
    bad = pushed_commit("feat: bad")
    cop(bad, "revert", REVERT.merge(GITHUB_STEP_SUMMARY: summary))

    assert_includes(File.read(summary), "Reverted #{bad} on trunk as #{origin_head}.\n")
  end

  def test_the_revert_starts_one_run_to_judge_it
    cop(pushed_commit("feat: bad"), "revert", REVERT)

    assert_equal(1, gh_log.scan("workflow run ci.yml --ref trunk").size)
  end

  def test_the_revert_leaves_no_bisect_branch
    bad = pushed_commit("feat: bad")
    git(@work, "push", "--quiet", "origin", "#{bad}:refs/heads/bisect/#{bad}")
    cop(bad, "revert", REVERT)

    assert_empty(origin_branches)
  end

  # The App's token is the only identity that the script may rely on: the run
  # has no git identity of its own.
  def test_the_revert_is_by_github_actions
    nobody = %i[GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL].to_h { |name| [name, nil] }
    cop(pushed_commit("feat: bad"), "revert", REVERT.merge(nobody))
    bot = "github-actions[bot] <41898282+github-actions[bot]@users.noreply.github.com>\n"
    by = git(@dir, "--git-dir", @origin, "log", "-1", "--format=%an <%ae>%n%cn <%ce>", "trunk")

    assert_equal(bot * 2, by)
  end

  def test_a_push_says_nothing_of_itself
    out = cop(pushed_commit("feat: bad"), "revert", REVERT)

    refute_match(/->|^To /, out)
  end

  def test_it_pushes_to_github_unless_told_another_server
    cop(pushed_commit("feat: bad"), "revert", REVERT.merge(GITHUB_SERVER_URL: nil))

    assert_includes(trunks_message, "This reverts commit")
  end

  def test_it_pushes_to_the_repository_that_the_environment_names
    bad = pushed_commit("feat: bad")
    cop(bad, "revert", REVERT.merge(GITHUB_REPOSITORY: "somebody/else"))

    assert_includes(trunks_message, "turned trunk red: somebody/else")
  end

  private def trunks_message
    git(@dir, "--git-dir", @origin, "log", "-1", "--format=%B", "trunk")
  end
end
