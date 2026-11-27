# frozen_string_literal: true

require_relative "support/fake_github"

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative "../tasks/github_api"

# How CI's scripts read GitHub's API: again after GitHub fails on its side, as
# it answers 502 now and then, and never again after an answer that says the
# request itself is wrong. FakeGitHub stands in for GitHub, at its paths.
class GitHubAPITest < Minitest::Test
  RUN = "/repos/setdef/stryker_for_ruby/actions/runs/1"
  WORKFLOW = "/repos/setdef/stryker_for_ruby/actions/workflows/ci.yml/runs"
  ITEM = { id: 1, event: "push", head_sha: "a", head_branch: "trunk", status: nil, conclusion: nil, run_attempt: 1 }
    .freeze
  private_constant(:RUN, :WORKFLOW, :ITEM)

  def test_asks_again_while_github_fails_on_its_side
    answers = [[502, "Bad Gateway"], [503, "Unavailable"], [200, '{"id":1}']]
    github = FakeGitHub.new(RUN => -> { answers.shift })

    assert_equal(1, reading(github) { |api| api.get("actions/runs/1") }["id"])
    assert_equal(3, github.requests.size)
  end

  def test_gives_up_after_its_attempts_and_says_what_github_answered
    github = FakeGitHub.new(RUN => [502, "Bad Gateway"])
    error = failing(github)

    assert_includes(error.message, "502 for GET")
    assert_includes(error.message, "Bad Gateway")
  end

  def test_asks_no_more_than_its_attempts
    github = FakeGitHub.new(RUN => [502, "Bad Gateway"])
    failing(github)

    assert_equal(GitHubAPI::ATTEMPTS, github.requests.size)
  end

  def test_does_not_ask_again_when_the_request_is_wrong
    github = FakeGitHub.new(RUN => [403, "rate limit exceeded"])
    error = failing(github)

    assert_includes(error.message, "403 for GET")
    assert_equal(1, github.requests.size)
  end

  def test_sends_the_token
    github = FakeGitHub.new(RUN => [200, "{}"])
    reading(github) { |api| api.get("actions/runs/1") }

    assert_equal(["Bearer secret"], github.authorizations)
  end

  def test_follows_every_page_of_a_list
    github = FakeGitHub.new(pages)

    jobs = reading(github) { |api| api.all("actions/runs/1/jobs", "jobs") }

    assert_equal((1..(GitHubAPI::PER_PAGE + 1)).to_a, jobs.map { |job| job["id"] })
  end

  def test_reads_the_runs_of_a_workflow_created_since_a_day
    query = "created=%3E%3D2026-11-20&exclude_pull_requests=true&branch=trunk&per_page=#{GitHubAPI::PER_PAGE}&page=1"
    github = FakeGitHub.new("#{WORKFLOW}?#{query}" => listing(workflow_runs: [ITEM]))

    runs = reading(github) { |api| api.runs("ci.yml", since: "2026-11-20", branch: "trunk") }

    assert_equal([[1, "trunk", nil]], runs.map { |item| [item.id, item.head_branch, item.html_url] })
  end

  def test_reads_the_jobs_of_the_latest_attempt_of_a_run
    job = { name: "Gate", conclusion: "success", run_attempt: 1 }
    github = FakeGitHub.new("#{RUN}/jobs?filter=latest&per_page=#{GitHubAPI::PER_PAGE}&page=1" => listing(jobs: [job]))
    run = GitHubAPI::Run.from_api(JSON.parse(JSON.generate(ITEM)))

    jobs = reading(github) { |api| api.jobs(run) }

    assert_equal([%w[Gate success]], jobs.map { |item| [item.name, item.conclusion] })
  end

  def test_an_item_of_a_list_that_is_no_object_is_refused
    error = failing_list(total_count: 2, jobs: [{ id: 1 }, "nope"])

    assert_includes(error.message, %("jobs" as "nope", not an Array of objects))
  end

  def test_a_list_that_is_no_array_is_refused
    assert_includes(failing_list(total_count: 1, jobs: {}).message, %("jobs" as {}, not an Array))
  end

  def test_a_list_without_its_key_is_refused
    assert_includes(failing_list(total_count: 0).message, %(with no "jobs"))
  end

  def test_a_full_page_without_a_total_is_refused
    jobs = Array.new(GitHubAPI::PER_PAGE) { { id: 1 } }

    assert_includes(failing_list(jobs:).message, %(with no "total_count"))
  end

  def test_an_answer_that_is_no_object_is_refused
    github = FakeGitHub.new(RUN => [200, "[]"])
    error = assert_raises(GitHubAPI::Error) { reading(github) { |api| api.get("actions/runs/1") } }

    assert_includes(error.message, "something other than a JSON object")
  end

  # Two pages, the first one full and the total one more than a page holds.
  private def pages
    full = Array.new(GitHubAPI::PER_PAGE) { |index| { id: index + 1 } }
    total = GitHubAPI::PER_PAGE + 1
    [full, [{ id: total }]].each_with_index.to_h do |jobs, page|
      ["#{RUN}/jobs?per_page=#{GitHubAPI::PER_PAGE}&page=#{page + 1}", [200, JSON.generate(total_count: total, jobs:)]]
    end
  end

  private def listing(**answer)
    [200, JSON.generate(total_count: 1, **answer)]
  end

  private def failing_list(**answer)
    path = "#{RUN}/jobs?per_page=#{GitHubAPI::PER_PAGE}&page=1"
    github = FakeGitHub.new(path => [200, JSON.generate(answer)])
    assert_raises(GitHubAPI::Error) { reading(github) { |api| api.all("actions/runs/1/jobs", "jobs") } }
  end

  private def reading(github)
    github.serving do
      yield(GitHubAPI.new(repository: "setdef/stryker_for_ruby", token: "secret", api: FakeGitHub::API, pause: 0))
    end
  end

  private def failing(github)
    assert_raises(GitHubAPI::Error) { reading(github) { |api| api.get("actions/runs/1") } }
  end
end
