# frozen_string_literal: true

require_relative "support/fake_github"

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative "../tasks/github_api"

# How CI's scripts read GitHub's API: again after GitHub fails on its side, as
# it answers 502 now and then, and never again after an answer that says the
# request itself is wrong. FakeGitHub stands in for GitHub, at its paths.
class GitHubAPITest < Minitest::Test
  RUN = "/repos/setdef/stryker_for_ruby/actions/runs/1"
  private_constant(:RUN)

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

  # Two pages, the first one full and the total one more than a page holds.
  private def pages
    full = Array.new(GitHubAPI::PER_PAGE) { |index| { id: index + 1 } }
    total = GitHubAPI::PER_PAGE + 1
    [full, [{ id: total }]].each_with_index.to_h do |jobs, page|
      ["#{RUN}/jobs?per_page=#{GitHubAPI::PER_PAGE}&page=#{page + 1}", [200, JSON.generate(total_count: total, jobs:)]]
    end
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
