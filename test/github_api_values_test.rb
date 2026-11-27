# frozen_string_literal: true

require_relative "support/fake_github"

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative "../tasks/github_api"

# How a run and a job are read from the objects that GitHub's API answers
# with: a member that is missing, or of another kind, raises where the object
# is read, and no nil travels on from there. An object is a Hash with symbol
# keys, which +JSON.generate+ turns into the strings that GitHub's API has.
class GitHubAPIValuesTest < Minitest::Test
  RUN = {
    id: 7,
    event: "push",
    head_sha: "a" * 40,
    head_branch: "trunk",
    status: "completed",
    conclusion: "success",
    run_attempt: 2,
    html_url: "https://github.test/runs/7",
  }.freeze
  JOB = { name: "Gate", conclusion: "failure", run_attempt: 2 }.freeze
  private_constant(:RUN, :JOB)

  def test_reads_a_run
    run = run_with

    assert_equal(
      [7, "push", "a" * 40, "trunk", "completed", "success", 2, "https://github.test/runs/7"],
      [run.id, run.event, run.head_sha, run.head_branch, run.status, run.conclusion, run.run_attempt, run.html_url]
    )
  end

  def test_reads_a_job
    job = job_with

    assert_equal(["Gate", "failure", 2], [job.name, job.conclusion, job.run_attempt])
  end

  def test_ignores_a_member_it_does_not_read
    assert_equal(job_with, job_with(id: 9))
  end

  %i[id event head_sha head_branch status conclusion run_attempt].each do |key|
    define_method(:"test_a_run_without_#{key}_is_refused") do
      error = assert_raises(GitHubAPI::Error) { GitHubAPI::Run.from_api(wire(RUN.except(key))) }

      assert_equal("GitHub's API answered a run with no #{key.to_s.inspect}", error.message)
    end
  end

  %i[name conclusion run_attempt].each do |key|
    define_method(:"test_a_job_without_#{key}_is_refused") do
      error = assert_raises(GitHubAPI::Error) { GitHubAPI::Job.from_api(wire(JOB.except(key))) }

      assert_equal("GitHub's API answered a job with no #{key.to_s.inspect}", error.message)
    end
  end

  # A run that has not finished has no conclusion, and GitHub says so with null.
  def test_a_run_that_has_not_finished_has_no_conclusion
    assert_nil(run_with(status: "in_progress", conclusion: nil).conclusion)
  end

  def test_a_run_may_have_no_branch_and_no_status
    run = run_with(head_branch: nil, status: nil)

    assert_equal([nil, nil], [run.head_branch, run.status])
  end

  def test_a_run_may_have_no_link
    absent = GitHubAPI::Run.from_api(wire(RUN.except(:html_url)))

    assert_equal([nil, nil], [absent, run_with(html_url: nil)].map(&:html_url))
  end

  def test_a_run_whose_id_is_not_an_integer_is_refused
    error = assert_raises(GitHubAPI::Error) { run_with(id: "7") }

    assert_equal(%(GitHub's API answered a run with "id" as "7", not an Integer), error.message)
  end

  def test_a_run_whose_event_is_not_a_string_is_refused
    error = assert_raises(GitHubAPI::Error) { run_with(event: nil) }

    assert_equal(%(GitHub's API answered a run with "event" as nil, not a String), error.message)
  end

  def test_a_job_whose_conclusion_is_not_a_string_is_refused
    error = assert_raises(GitHubAPI::Error) { job_with(conclusion: 1) }

    assert_equal(%(GitHub's API answered a job with "conclusion" as 1, not a String or null), error.message)
  end

  def test_a_run_whose_link_is_not_a_string_is_refused
    assert_raises(GitHubAPI::Error) { run_with(html_url: 1) }
  end

  private def wire(object)
    JSON.parse(JSON.generate(object))
  end

  private def run_with(**changes)
    GitHubAPI::Run.from_api(wire(RUN.merge(changes)))
  end

  private def job_with(**changes)
    GitHubAPI::Job.from_api(wire(JOB.merge(changes)))
  end
end
