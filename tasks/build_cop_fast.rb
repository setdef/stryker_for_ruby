# frozen_string_literal: true

require_relative "build_cop_step"

# Decides what the build cop does about a red run of fast.yml on trunk.
#
# fast.yml gives each push to trunk a run of its own, never canceled (see its
# concurrency), so a red run names exactly one commit and needs no bisecting.
# Its failed jobs run again once, so that a flake blames nobody. When they fail
# again, the commit is the one to revert, provided that its parent's run
# passed. When the parent's run failed or has not finished, the parent is
# judged first, and the cop comes back to this run on its next call. Like
# BuildCop, it judges the oldest red run on trunk that is not settled, since
# the newest green one.
class BuildCopFast
  # +runs+ are the CommitRuns of fast.yml.
  def initialize(runs)
    @runs = runs
  end

  # The BuildCopStep for trunk's +commits+, newest first, given +reverts+, the
  # TrunkReverts among them.
  def call(commits, reverts)
    good = commits.index { |commit| @runs.green_on_trunk?(commit) }
    return BuildCopStep.of(:none, "no commit has a green run of Fast on trunk") unless good

    bad = oldest_unsettled(commits, reverts, good)
    return BuildCopStep.of(:none, "no red run of Fast on trunk since #{commits[good]} is unsettled") unless bad

    judge(commits[bad], commits[bad + 1], @runs.red_run(commits[bad]))
  end

  # The index of the oldest commit newer than the one at +good+ whose run is
  # red, and that no newer commit has reverted.
  private def oldest_unsettled(commits, reverts, good)
    (0...good).reverse_each.find do |index|
      @runs.red_run(commits[index]) && !reverts.settled?(index, index + 1)
    end
  end

  private def judge(commit, parent, run)
    failed = @runs.failed_jobs(run)
    return stuck(run, commit, "has no job that failed to run again") if failed.empty?
    return rerun(run, commit, failed) unless @runs.failed_again?(run, failed)

    judge_parent(commit, parent, run, failed)
  end

  private def judge_parent(commit, parent, run, failed)
    state = @runs.state_on_trunk(parent)
    return revert(run, commit, failed) if state == :good
    return wait(commit, parent, state) if %i[pending bad].include?(state)

    stuck(run, commit, "failed again, and its parent #{parent} has no run of Fast that passed or failed")
  end

  private def rerun(run, commit, failed)
    reason = "run #{run.id} of Fast on #{commit} failed #{failed.join(', ')}, and a second attempt tells a flake apart"
    BuildCopStep.of(:rerun, reason, commit:, run: run.id)
  end

  private def revert(run, commit, failed)
    reason = "run #{run.id} of Fast on #{commit} failed #{failed.join(', ')} again on attempt " \
      "#{run.run_attempt}, and the run of its parent passed"
    BuildCopStep.of(:revert, reason, commit:, run: run.id)
  end

  private def wait(commit, parent, state)
    told = (state == :bad) ? "failed" : "has not finished"
    BuildCopStep.of(:wait, "the run of Fast on #{parent}, the parent of #{commit}, #{told}; it is judged first")
  end

  private def stuck(run, commit, because)
    BuildCopStep.of(:stuck, "run #{run.id} of Fast on #{commit} #{because}")
  end
end
