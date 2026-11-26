# frozen_string_literal: true

require_relative "build_cop_blame"
require_relative "build_cop_step"
require_relative "commit_runs"
require_relative "github_api"

# Finds the commit that turned trunk's full run red, one step at a time, from
# GitHub's API alone.
#
# A full run of ci.yml on trunk covers a batch: every commit pushed since the
# run before it started (see the top of build-cop.yml). When a batch goes red
# after a green one, any of its commits may be the one at fault. This class
# bisects the batch with full runs of single commits, started on branches
# <tt>bisect/SHA</tt>, and judges each by the jobs that failed in the red run.
# BuildCopBlame decides about the first bad commit, which it names to revert
# once the commit's failed jobs have failed twice and its parent has passed
# them.
#
# It keeps no state: each call reads the runs as they are and says what to do
# next, so .github/workflows/build-cop.yml can call it whenever a run ends and
# on a schedule, and a call that finds the work in progress says to wait.
#
#   ruby -r ./tasks/build_cop -e "BuildCop.main(ARGV[0])" COMMITS
#
# reads trunk's commits, newest first, one per line, from the file COMMITS
# (git rev-list --first-parent), and prints what to do as lines +action=+,
# +commit=+, +run=+, and +reason=+, for GITHUB_OUTPUT. It reads
# GITHUB_REPOSITORY, GITHUB_API_URL, and GH_TOKEN.
class BuildCop
  # The workflow bisected.
  WORKFLOW = "ci.yml"
  public_constant(:WORKFLOW)

  # The branch a commit's bisecting run is started on.
  BISECT = "bisect/"
  public_constant(:BISECT)

  # The verdict on the commit that a green run on trunk has passed.
  GOOD = CommitRuns::Verdict.new(:good, nil)
  private_constant(:GOOD)

  # How far back runs are read: a red batch older than this is a person's.
  DAYS = 3
  private_constant(:DAYS)

  # Prints the next step for the commits listed in the file at +path+, as
  # +to_output+ gives it, from the repository and token that +env+ names
  # (GITHUB_REPOSITORY, GH_TOKEN, and GITHUB_API_URL when it is not GitHub's).
  # When GitHub's API fails, it ends the run with the failure's message, as an
  # error annotation inside GitHub Actions.
  def self.main(path, env: ENV, out: $stdout, now: Time.now)
    api = env.fetch("GITHUB_API_URL", "https://api.github.com")
    cop = new(repository: env["GITHUB_REPOSITORY"], token: env["GH_TOKEN"], api:, now:)
    out.print(cop.call(File.readlines(path, chomp: true).reject(&:empty?)).to_output)
  rescue GitHubAPI::Error => e
    abort("#{'::error::' if env['GITHUB_ACTIONS']}#{e.message}")
  end

  # +now+ is the time runs are read back from, by DAYS.
  def initialize(repository:, token:, api: "https://api.github.com", pause: 5, now: Time.now)
    @github = GitHubAPI.new(repository:, token:, api:, pause:)
    @since = (now - (DAYS * 86_400)).utc.strftime("%Y-%m-%d")
  end

  # The next BuildCopStep for trunk's +commits+, newest first.
  def call(commits)
    path = "actions/workflows/#{WORKFLOW}/runs"
    runs = @github.all(path, "workflow_runs", created: ">=#{@since}", exclude_pull_requests: true)
    @runs = CommitRuns.new(runs, @github)
    step(commits)
  end

  private def step(commits)
    good = commits.index { |commit| @runs.green_on_trunk?(commit) }
    return BuildCopStep.of(:none, "no commit of the last #{DAYS} days has a green run on trunk") unless good

    bad = commits.take(good).rindex { |commit| @runs.red_run(commit) }
    return BuildCopStep.of(:none, "no run on trunk since #{commits[good]}'s green one is red") unless bad

    judge(@runs.red_run(commits[bad]), commits[bad..good].reverse)
  end

  private def judge(red, commits)
    failed = @runs.failed_jobs(red)
    return narrow(commits, failed) unless failed.empty?

    BuildCopStep.of(:none, "run #{red['id']} has no job that failed, only ones cancelled or no runner took")
  end

  # Bisects +commits+, oldest first, the first green and the last red, by
  # whether each commit's newest run failed a job of +failed+.
  private def narrow(commits, failed)
    rest = commits.drop(1)
    verdicts = [GOOD, *rest.map { |commit| @runs.verdict(commit, failed) }]
    high = verdicts.index { |verdict| verdict.state == :bad }
    return BuildCopStep.of(:wait, "the run of #{commits.last} is running again") unless high

    low = verdicts.take(high).rindex { |verdict| verdict.state == :good }
    return blame(commits, verdicts, failed, high) if high - low == 1

    halve(commits, verdicts, failed, low..high)
  end

  private def blame(commits, verdicts, failed, high)
    BuildCopBlame.new(@runs, BISECT).call(commits[high], verdicts[high].run, failed, commits[high - 1])
  end

  # Halves the commits between the last good one and the first bad one, once
  # none of them has a run that has not finished.
  private def halve(commits, verdicts, failed, range)
    unfinished = pending(verdicts, range)
    return BuildCopStep.of(:wait, "a run of #{commits[unfinished]} has not finished") if unfinished

    middle = (range.begin + range.end) / 2
    return BuildCopStep.unsettled(commits[middle], verdicts[middle].run, failed) if verdicts[middle].state == :unknown

    BuildCopStep.of(:bisect, between(commits, failed, range), commit: commits[middle])
  end

  private def pending(verdicts, range)
    ((range.begin + 1)...(range.end)).find { |index| verdicts[index].state == :pending }
  end

  private def between(commits, failed, range)
    "#{commits[range.begin]} passed #{failed.join(', ')} and #{commits[range.end]} failed; " \
      "#{range.end - range.begin - 1} commits between"
  end
end
