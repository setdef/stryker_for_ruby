# frozen_string_literal: true

# What the build cop is to do next: +action+ is :none, :wait, :bisect, :rerun,
# :revert, or :stuck; +commit+ is the commit to bisect or revert, +run+ the run
# to run again, and +reason+ says why, for a person.
class BuildCopStep < Data.define(:action, :commit, :run, :reason)
  # A step of the given +action+, with +commit+ and +run+ when it has them.
  def self.of(action, reason, commit: nil, run: nil)
    new(action:, commit:, run:, reason:)
  end

  # The step for the +run+ of +commit+ that finished without passing or
  # failing a job named in +failed+, as when no runner took one or a job it
  # needs failed: its failed jobs run again once, and then it is a person's. A
  # run that finished green has no failed job, and the API refuses to run
  # again what did not fail.
  def self.unsettled(commit, run, failed)
    told = "run #{run['id']} of #{commit} finished without passing or failing #{failed.join(', ')}"
    return of(:stuck, "#{told}, and is green, so it has no failed job to run again") if run["conclusion"] == "success"
    return of(:rerun, "#{told}; its failed jobs run again", commit:, run: run["id"]) if run["run_attempt"] == 1

    of(:stuck, "#{told}, on attempt #{run['run_attempt']}")
  end

  # Whether the step changes something: a run runs again, or a commit is
  # reverted.
  def acts?
    %i[rerun revert].include?(action)
  end

  # The lines GITHUB_OUTPUT takes.
  def to_output
    "action=#{action}\ncommit=#{commit}\nrun=#{run}\nreason=#{reason}\n"
  end
end
