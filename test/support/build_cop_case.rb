# frozen_string_literal: true

require_relative "fake_github"

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative "../../tasks/build_cop"
require "json"
require "uri"

# Helpers for the tests of how the build cop finds the commit that turned
# trunk's full run red. Each case is a trunk of six commits, A the oldest and F
# the newest, whose runs FakeGitHub serves at GitHub's paths, in the shape
# GitHub's API gives them. A run is a Hash with symbol keys, which
# +JSON.generate+ turns into the strings GitHub's API has.
module BuildCopCase
  COMMITS = ("a".."f").map { |name| name * 40 }
    .freeze
  private_constant(:COMMITS)

  NOW = Time.utc(2026, 11, 23, 12)
  REPOSITORY = "setdef/stryker_for_ruby"
  private_constant(:NOW, :REPOSITORY)

  # The job that failed in F's run, and another that the failure leaves be.
  FAILED = "Gate on Ruby 4.0, windows-latest"
  OTHER = "Tests on Prism 1.7.0, Ruby 4.0"
  private_constant(:FAILED, :OTHER)

  # The jobs of fast.yml, and the query the cop reads its runs with.
  FAST_GATE = "Gate on Ruby 4.0, ubuntu-latest"
  FAST_FAILED = "Tests on Ruby 4.0, windows-latest"
  FAST_QUERY = { branch: "trunk", event: "push" }.freeze
  private_constant(:FAST_GATE, :FAST_FAILED, :FAST_QUERY)

  # The commit that +name+ stands for.
  def commit(name)
    name * 40
  end

  # A run of +name+'s commit: +conclusion+ nil for one still running. +fields+
  # replace what the run has by default: a push to trunk on its first attempt,
  # with the job that failed concluding as the run does.
  def ci_run(name, id, conclusion, **fields)
    attempt = fields.fetch(:run_attempt, 1)
    state = (conclusion == "failure") ? "failure" : "success"
    push = { id:, head_sha: commit(name), head_branch: "trunk", event: "push", run_attempt: attempt }
    ending = { status: conclusion ? "completed" : "in_progress", conclusion:, jobs: [job(FAILED, state, attempt)] }
    push.merge(ending, fields)
  end

  # A run of +name+'s commit on its bisect branch.
  def bisect_run(name, id, conclusion, **fields)
    ci_run(name, id, conclusion, head_branch: "bisect/#{name}", **fields)
  end

  # The second attempt of +name+'s run on its bisect branch, in which the job
  # that failed fails again.
  def second_failure(name, id)
    bisect_run(name, id, "failure", run_attempt: 2, jobs: [job(FAILED, "failure", 2)])
  end

  def job(name, conclusion, attempt = 1)
    { name:, status: "completed", conclusion:, run_attempt: attempt }
  end

  # The runs of a trunk that was green at +green+ and is red at F.
  def red_batch(green)
    [ci_run(green, 1, "success"), ci_run("f", 2, "failure")]
  end

  # A run of fast.yml on trunk for +name+'s commit, with ids from 100 up, so
  # that no run of ci.yml has the same. Its jobs are the two that fast.yml
  # has, and the one that failed is the one on Windows.
  def fast_run(name, id, conclusion, jobs: nil, **fields)
    attempt = fields.fetch(:run_attempt, 1)
    state = (conclusion == "failure") ? "failure" : "success"
    jobs ||= [job(FAST_GATE, "success", attempt), job(FAST_FAILED, state, attempt)]
    ci_run(name, id + 100, conclusion, jobs:, **fields)
  end

  # The second attempt of a run of fast.yml for +name+'s commit, in which the
  # job that failed fails again.
  def fast_failed_again(name, id)
    jobs = [job(FAST_GATE, "success", 1), job(FAST_FAILED, "failure", 2)]
    fast_run(name, id, "failure", run_attempt: 2, jobs:)
  end

  # The cop's step for COMMITS, newest first, with +runs+ of ci.yml and +fast+
  # runs of fast.yml served, and +reverts+ as pairs of the commit that reverts
  # and the commit it reverts.
  def cop(*runs, reverts: [], fast: [])
    serve(*runs, fast:) do
      cop = BuildCop.new(repository: REPOSITORY, token: "secret", api: FakeGitHub::API, pause: 0, now: NOW)
      cop.call(COMMITS.reverse, reverts)
    end
  end

  # Serves +runs+ at GitHub's paths while the block runs.
  def serve(*runs, fast: [], &)
    github_serving(routes(runs, "ci.yml").merge(routes(fast, "fast.yml", **FAST_QUERY)), &)
  end

  # Calls the block while the +routes+ are served.
  def github_serving(routes, &)
    FakeGitHub.new(routes).serving(&)
  end

  private def routes(runs, workflow, **query)
    listing = runs.map { |run| run.except(:jobs) }
    routes = { runs_path(workflow, **query) => [200, JSON.generate(total_count: runs.size, workflow_runs: listing)] }
    runs.each do |run|
      routes[jobs_path(run[:id])] = [200, JSON.generate(total_count: run[:jobs].size, jobs: run[:jobs])]
    end
    routes
  end

  private def runs_path(workflow, **query)
    query = URI.encode_www_form(created: ">=2026-11-20", exclude_pull_requests: true, **query, per_page: 50, page: 1)
    "/repos/#{REPOSITORY}/actions/workflows/#{workflow}/runs?#{query}"
  end

  private def jobs_path(id)
    "/repos/#{REPOSITORY}/actions/runs/#{id}/jobs?filter=latest&per_page=50&page=1"
  end
end
