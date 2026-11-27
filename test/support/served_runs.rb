# frozen_string_literal: true

require_relative "fake_github"
require "json"
require "uri"

# Trunk's commits, and the runs of ci.yml that FakeGitHub serves for them, for
# the tests of the release's choice of a commit.
module ServedRuns
  REPOSITORY = "setdef/stryker_for_ruby"
  public_constant(:REPOSITORY)

  def commits
    @commits ||= %w[a b].map { |name| name * 40 }
  end

  def list_of_commits
    path = File.join(@dir, "commits.txt")
    File.write(path, "#{commits.reverse.join("\n")}\n\n")
    path
  end

  # A run of ci.yml on a push to trunk of +commit+ that passed.
  def passed_run(commit, id)
    {
      id:,
      head_sha: commit,
      head_branch: "trunk",
      event: "push",
      run_attempt: 1,
      status: "completed",
      conclusion: "success",
    }
  end

  # Serves +runs+, each with one job that passed, while the block runs.
  def serving(runs, &)
    query = URI.encode_www_form(created: ">=2026-11-12", exclude_pull_requests: true, per_page: 50, page: 1)
    listing = [200, JSON.generate(total_count: runs.size, workflow_runs: runs)]
    routes = { "/repos/#{REPOSITORY}/actions/workflows/ci.yml/runs?#{query}" => listing }
    jobs = [{ name: "Gate", status: "completed", conclusion: "success", run_attempt: 1 }]
    runs.each do |run|
      routes["/repos/#{REPOSITORY}/actions/runs/#{run[:id]}/jobs?filter=latest&per_page=50&page=1"] =
        [200, JSON.generate(total_count: 1, jobs:)]
    end
    FakeGitHub.new(routes).serving(&)
  end
end
