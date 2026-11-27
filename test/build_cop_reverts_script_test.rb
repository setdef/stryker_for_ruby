# frozen_string_literal: true

require_relative "support/build_cop_script_case"

# The file of reverts that .github/scripts/build-cop.sh gives the task: each
# commit of trunk that says it reverts one, and the commit it reverts. A red
# run stops blocking the cop once a commit it covers has been reverted.
class BuildCopRevertsScriptTest < Minitest::Test
  include BuildCopScriptCase

  def test_it_lists_each_revert_with_the_commit_it_reverts
    bad = pushed_commit("feat: bad")
    git(@work, "revert", "--no-edit", bad)
    git(@work, "push", "--quiet", "origin", "trunk")
    cop(origin_head, "wait")

    assert_equal("#{origin_head} #{bad}\n", reverts_seen)
  end

  def test_it_lists_none_when_trunk_has_no_revert
    cop(pushed_commit("feat: x"), "wait")

    assert_equal("", reverts_seen)
  end

  # Only a line that names a commit by its full hash is a revert.
  def test_a_message_that_only_mentions_a_revert_is_no_revert
    commit("fix: undo\n\nThis reverts commit abc, in a way.", "x.txt", "x\n")
    git(@work, "push", "--quiet", "origin", "trunk")
    cop(origin_head, "wait")

    assert_equal("", reverts_seen)
  end

  # A revert that a later commit reverted is listed too: the task reads both.
  def test_a_revert_of_a_revert_is_listed_as_well
    bad = pushed_commit("feat: bad")
    git(@work, "revert", "--no-edit", bad)
    first = git(@work, "rev-parse", "HEAD").strip
    git(@work, "revert", "--no-edit", first)
    git(@work, "push", "--quiet", "origin", "trunk")
    cop(origin_head, "wait")

    assert_equal(["#{origin_head} #{first}", "#{first} #{bad}"], reverts_seen.lines(chomp: true))
  end
end
