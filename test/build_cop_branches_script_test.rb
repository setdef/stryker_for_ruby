# frozen_string_literal: true

require_relative "support/build_cop_script_case"

# Which of the origin's refs .github/scripts/build-cop.sh deletes, and when:
# the branches named bisect/, once nothing is red, and no other ref, and not
# while a run it started on one has yet to end.
class BuildCopBranchesScriptTest < Minitest::Test
  include BuildCopScriptCase

  def test_it_deletes_no_tag_named_like_a_bisect_branch
    bad = bisect_commit(WITH_DISPATCH)
    git(@work, "tag", "bisect/keep", bad)
    git(@work, "push", "--quiet", "origin", "refs/tags/bisect/keep")
    cop(bad, "none")

    assert_includes(git(@dir, "--git-dir", @origin, "tag", "--list"), "bisect/keep")
  end

  def test_it_deletes_the_branches_named_bisect_when_there_is_a_tag_of_the_name_too
    bad = bisect_commit(WITH_DISPATCH)
    git(@work, "tag", "bisect/keep", bad)
    git(@work, "push", "--quiet", "origin", "refs/tags/bisect/keep", "#{bad}:refs/heads/bisect/#{bad}")
    cop(bad, "none")

    assert_empty(origin_branches.strip)
  end

  def test_it_leaves_the_branches_while_a_run_has_not_finished
    bad = bisect_commit(WITH_DISPATCH)
    git(@work, "push", "--quiet", "origin", "#{bad}:refs/heads/bisect/#{bad}")
    cop(bad, "wait")

    assert_includes(origin_branches, "bisect/#{bad}")
  end
end
