# frozen_string_literal: true

require_relative "../json_reader"

class GitHubAPI
  # One run of a workflow, as GitHub's API gives it: the members that the build
  # cop and the release read, each of the kind GitHub documents. Two runs with
  # equal members are equal.
  #
  # +id+:: the run's number, which no other run of the repository has
  # +event+:: what started the run, such as +push+ or +workflow_dispatch+
  # +head_sha+:: the commit that the run checked out
  # +head_branch+:: the branch the run started on, or nil
  # +status+:: +queued+, +in_progress+, or +completed+, or nil
  # +conclusion+:: how a completed run ended, such as +success+ or +failure+,
  #                and nil until then
  # +run_attempt+:: which attempt the run is, from 1: running the failed jobs
  #                 again makes the next attempt of the same run
  # +html_url+:: the address of the run's page, or nil when GitHub gave none
  class Run < Data.define(:id, :event, :head_sha, :head_branch, :status, :conclusion, :run_attempt, :html_url)
    # Reads a run from +object+, one item of what GitHub's API answers with.
    # Raises GitHubAPI::Error for a missing member, except +html_url+, and for
    # one of another kind.
    def self.from_api(object)
      reader = JSONReader.new(object, "GitHub's API answered a run", Error)
      new(**identity(reader), **progress(reader))
    end

    # The members that say which run it is, and what started it.
    def self.identity(reader)
      {
        id: reader.integer("id"),
        event: reader.string("event"),
        head_sha: reader.string("head_sha"),
        head_branch: reader.string_or_nil("head_branch"),
        html_url: reader.optional_string("html_url"),
      }
    end
    private_class_method(:identity)

    # The members that say how far the run got, and how it ended.
    def self.progress(reader)
      {
        status: reader.string_or_nil("status"),
        conclusion: reader.string_or_nil("conclusion"),
        run_attempt: reader.integer("run_attempt"),
      }
    end
    private_class_method(:progress)

    # @dynamic id, event, head_sha, head_branch, status, conclusion, run_attempt, html_url
  end
end
