# frozen_string_literal: true

require_relative "../json_reader"

class GitHubAPI
  # One job of a run, as GitHub's API gives it: the members that the build cop
  # and the release read. Two jobs with equal members are equal.
  #
  # +name+:: the job's name, as the workflow gives it
  # +conclusion+:: how a finished job ended, such as +success+ or +skipped+,
  #                and nil until then
  # +run_attempt+:: which attempt of the run the job belongs to, from 1
  class Job < Data.define(:name, :conclusion, :run_attempt)
    # Reads a job from +object+, one item of what GitHub's API answers with.
    # Raises GitHubAPI::Error for a missing member, and for one of another
    # kind.
    def self.from_api(object)
      reader = JSONReader.new(object, "GitHub's API answered a job", Error)
      new(
        name: reader.string("name"),
        conclusion: reader.string_or_nil("conclusion"),
        run_attempt: reader.integer("run_attempt")
      )
    end

    # @dynamic name, conclusion, run_attempt
  end
end
