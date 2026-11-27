# frozen_string_literal: true

require_relative "support/fake_github"

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative "../tasks/commit_runs"
require_relative "../tasks/github_api"

# tasks/commit_runs.rb: the verdict on a commit rests on a run, except the
# verdict that a commit has no run.
class CommitRunsTest < Minitest::Test
  RUN = {
    id: 1,
    event: "push",
    head_sha: "a",
    head_branch: "trunk",
    status: "completed",
    conclusion: "success",
    run_attempt: 1,
  }.freeze
  private_constant(:RUN)

  def test_a_verdict_gives_the_run_it_rests_on
    run = GitHubAPI::Run.from_api(JSON.parse(JSON.generate(RUN)))

    assert_same(run, CommitRuns::Verdict.new(:good, run).run!)
  end

  def test_a_verdict_that_has_no_run_refuses_to_give_one
    error = assert_raises(KeyError) { CommitRuns::Verdict.new(:none, nil).run! }

    assert_equal("a verdict of none rests on no run", error.message)
  end
end
