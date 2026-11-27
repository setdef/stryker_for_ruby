# frozen_string_literal: true

require_relative "commit_runs"

# Picks the commit of trunk that a release is made from: one whose run of
# ci.yml passed, wherever trunk has moved since (.github/workflows/release.yml).
#
# CI covers every commit pushed since the run before it started, and only the
# newest of them has a run of its own, so a commit with no green run is no
# release candidate, though the commits after it may be.
class ReleaseCommit
  # No commit can be released.
  class Refusal < StandardError; end

  # +runs+ are the CommitRuns of ci.yml.
  def initialize(runs)
    @runs = runs
  end

  # The commit to release: +requested+ when it is among trunk's +commits+ and
  # passed, else the newest of +commits+ that passed.
  def call(commits, requested = nil)
    return newest(commits) unless requested

    check(commits, requested)
    requested
  end

  private def check(commits, requested)
    raise(Refusal, "#{requested} is not among trunk's last #{commits.size} commits") unless commits.include?(requested)
    return if @runs.green_on_trunk?(requested)

    raise(Refusal, "#{requested} has no run of ci.yml on trunk that passed every job")
  end

  private def newest(commits)
    commits.find { |commit| @runs.green_on_trunk?(commit) } or
      raise(Refusal, "none of trunk's last #{commits.size} commits has a run of ci.yml on trunk that passed every job")
  end
end
