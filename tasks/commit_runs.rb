# frozen_string_literal: true

# What the runs of ci.yml say about each commit of trunk: which commits a run
# on trunk passed, which it failed, and whether the jobs that failed in one
# run passed, failed, or never ran in the newest run of another commit.
#
# BuildCop reads the runs through this class, and decides what to do about
# them. A run is a Hash as GitHub's API gives it, and the class reads each
# run's jobs from the API once.
class CommitRuns
  # The verdict on one commit: +state+ is :good, :bad, :pending, :unknown, or
  # :none, and +run+ is the run it rests on, which :none has not got.
  Verdict = Data.define(:state, :run)
  public_constant(:Verdict)

  # The events whose runs check out their commit itself. A pull request's run
  # checks out a merge, and says nothing of the commit.
  EVENTS = %w[push workflow_dispatch].freeze
  private_constant(:EVENTS)

  # The conclusions of a run or a job that count as a failure. A conclusion of
  # canceled, skipped, or neutral is not one, and action_required is a run that
  # has not finished: it waits for a person's approval.
  FAILURES = %w[failure timed_out].freeze
  private_constant(:FAILURES)

  # The conclusion of a run or a job that waits for a person's approval.
  APPROVAL = "action_required"
  private_constant(:APPROVAL)

  # The branch whose runs are trunk's.
  TRUNK = "trunk"
  private_constant(:TRUNK)

  # +runs+ are the runs of ci.yml, and +github+ the GitHubAPI that reads each
  # run's jobs.
  def initialize(runs, github)
    @by_commit = runs.select { |run| EVENTS.include?(run["event"]) }
      .group_by { |run| run["head_sha"] }
    @github = github
    @jobs = {}
  end

  # Whether a run on trunk passed every job it has for +commit+. A run with a
  # job skipped says nothing of what a full run covers.
  def green_on_trunk?(commit)
    trunk_runs(commit).any? { |run| green?(run) }
  end

  # The newest run on trunk for +commit+ that failed, or nil.
  def red_run(commit)
    trunk_runs(commit).find { |run| failed?(run) }
  end

  # The names of the jobs that failed in +run+.
  def failed_jobs(run)
    jobs(run).filter_map { |job| job["name"] if failed?(job) }
  end

  # Whether a job of +run+ named in +names+ failed on a second attempt or
  # later, which tells a failure from a flake.
  def failed_again?(run, names)
    jobs(run).any? { |job| names.include?(job["name"]) && failed?(job) && job["run_attempt"] > 1 }
  end

  # The Verdict for +commit+'s newest run that was not canceled, by the jobs
  # named +failed+. With +only+, the runs counted are those on branches that
  # start with it.
  def verdict(commit, failed, only: nil)
    run = newest(commit, only)
    return Verdict.new(:none, nil) unless run

    Verdict.new(state(run, failed), run)
  end

  private def newest(commit, only)
    runs = @by_commit.fetch(commit, []).reject { |run| run["conclusion"] == "cancelled" }
    runs = runs.select { |run| run["head_branch"].start_with?(only) } if only
    runs.max_by { |run| run["id"] }
  end

  private def state(run, failed)
    return :pending if unfinished?(run)

    mine = jobs(run).select { |job| failed.include?(job["name"]) }
    return :bad if mine.any? { |job| failed?(job) }
    return :good if passed?(mine, failed)

    :unknown
  end

  private def passed?(jobs, names)
    jobs.size == names.size && jobs.all? { |job| job["conclusion"] == "success" }
  end

  private def green?(run)
    return false unless run["conclusion"] == "success"

    all = jobs(run)
    all.any? && all.all? { |job| job["conclusion"] == "success" }
  end

  private def trunk_runs(commit)
    runs = @by_commit.fetch(commit, []).select { |run| run["head_branch"] == TRUNK && finished?(run) }
    runs.sort_by { |run| -run["id"] }
  end

  private def failed?(run_or_job)
    FAILURES.include?(run_or_job["conclusion"])
  end

  private def finished?(run)
    run["status"] == "completed" && run["conclusion"] != APPROVAL
  end

  # A run that is going, or that has a job waiting for a person's approval.
  private def unfinished?(run)
    !finished?(run) || jobs(run).any? { |job| job["conclusion"] == APPROVAL }
  end

  private def jobs(run)
    @jobs[[run["id"], run["run_attempt"]]] ||= @github.all("actions/runs/#{run['id']}/jobs", "jobs", filter: "latest")
  end
end
