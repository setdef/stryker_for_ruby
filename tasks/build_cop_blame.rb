# frozen_string_literal: true

require_relative "build_cop_step"

# Decides what the build cop does about the first bad commit of a batch, the
# commit right after the last good one.
#
# A job that failed in the commit's run is run again, so that a flake blames
# nobody. When it fails again, the commit's parent has to pass the same jobs in
# a run of its own on a bisect branch, after trunk went red. A failure that
# outlasts a rerun, as a rate limit of a mirror may, fails every run alike,
# and the batch's oldest commit would take the blame while its parent, whose
# only green run is older than the failure, was never run again. If the parent
# fails them too, the cause is outside the batch, and nothing is reverted.
class BuildCopBlame
  # +runs+ are the CommitRuns to read, and +prefix+ is the start of the names
  # of the branches that the cop's bisecting runs are on.
  def initialize(runs, prefix)
    @runs = runs
    @prefix = prefix
  end

  # The BuildCopStep for +commit+, whose newest run is +run+, when +failed+ are
  # the names of the jobs that failed, and +parent+ is the commit before it.
  def call(commit, run, failed, parent)
    return rerun(commit, run, failed) unless @runs.failed_again?(run, failed)

    proof = @runs.verdict(parent, failed, only: @prefix)
    case proof.state
    when :none then bisect_parent(commit, run, failed, parent)
    when :pending then BuildCopStep.of(:wait, "the run of #{parent}, the parent of #{commit}, has not finished")
    when :good then revert(commit, run, failed, proof.run!)
    when :bad then outside(commit, failed, parent, proof.run!)
    else BuildCopStep.unsettled(parent, proof.run!, failed)
    end
  end

  private def rerun(commit, run, failed)
    reason = "run #{run.id} of #{commit} failed #{failed.join(', ')}, its parent passed, and a second " \
      "attempt tells a flake apart"
    BuildCopStep.of(:rerun, reason, commit:, run: run.id)
  end

  private def bisect_parent(commit, run, failed, parent)
    reason = "run #{run.id} of #{commit} failed #{failed.join(', ')} again, and its parent #{parent} has " \
      "had no run since trunk went red; it is run before #{commit} is blamed"
    BuildCopStep.of(:bisect, reason, commit: parent)
  end

  private def revert(commit, run, failed, parent_run)
    reason = "run #{run.id} of #{commit} failed #{failed.join(', ')} again on attempt #{run.run_attempt}, " \
      "and run #{parent_run.id} of its parent passed them"
    BuildCopStep.of(:revert, reason, commit:, run: run.id)
  end

  private def outside(commit, failed, parent, parent_run)
    reason = "the cause is outside the batch: run #{parent_run.id} of #{parent}, the parent of #{commit}, " \
      "failed #{failed.join(', ')} too (#{parent_run.html_url || parent_run.id})"
    BuildCopStep.of(:stuck, reason)
  end
end
