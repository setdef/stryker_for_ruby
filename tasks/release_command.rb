# frozen_string_literal: true

require_relative "github_api"
require_relative "release"
require_relative "release_assets"
require_relative "release_commit"

# The command that .github/scripts/release.sh runs, one step of a release at a
# time (.github/workflows/release.yml):
#
#   ruby -r ./tasks/release_command -e 'ReleaseCommand.main(ARGV)' COMMAND ARGUMENT...
#
#   version [TAG]           prints the version TAG releases, or, with no tag,
#                           the version after the newest release
#   commit COMMITS [SHA]    prints the commit to release: SHA, or the newest of
#                           the commits listed in the file COMMITS (newest
#                           first) whose run of ci.yml passed
#   notes SHA FILE          writes the notes of a release of SHA to FILE
#   stamp VERSION           writes VERSION into the version file
#   assets DIR VERSION      checks that DIR holds the gem of VERSION, and writes
#                           SHA256SUMS beside it
#   record VERSION SHA      writes the release of VERSION from SHA into
#                           CHANGELOG.md and the version file
#
# It reads GITHUB_REPOSITORY, GITHUB_API_URL, and GH_TOKEN for +commit+. A step
# GitHub's API or the repository refuses ends the run with the reason, as an
# error annotation inside GitHub Actions.
class ReleaseCommand
  # How far back runs of ci.yml are read: a commit older than this has no run
  # to release it by.
  DAYS = 14
  public_constant(:DAYS)

  # Takes the step +argv+ names, from the folder +root+.
  def self.main(argv, env: ENV, out: $stdout, root: Dir.pwd, now: Time.now)
    new(env:, out:, root:, now:).call(*argv)
  rescue Release::Refusal, ReleaseCommit::Refusal, ReleaseAssets::Refusal, GitHubAPI::Error, ArgumentError => e
    abort("#{'::error::' if env['GITHUB_ACTIONS']}#{e.message}")
  end

  def initialize(env:, out:, root:, now:)
    @env = env
    @out = out
    @release = Release.new(root:)
    @now = now
  end

  # Runs the step +command+ with +arguments+.
  def call(command = nil, *)
    case command
    when "version" then version(*)
    when "commit" then commit(*)
    when "notes" then notes(*)
    when "stamp" then @release.stamp(*)
    when "assets" then assets(*)
    when "record" then record(*)
    else raise(ArgumentError, "unknown step #{command.inspect}; see tasks/release_command.rb")
    end
  end

  private def version(tag = nil)
    @out.puts(tag ? @release.version(tag) : @release.next_version)
  end

  private def commit(path, requested = nil)
    commits = File.readlines(path, chomp: true).reject(&:empty?)
    @out.puts(ReleaseCommit.new(runs).call(commits, requested))
  end

  private def notes(sha, path)
    File.write(path, @release.notes(sha))
  end

  private def assets(dir, version)
    assets = ReleaseAssets.new(dir)
    assets.check(version)
    @out.print(assets.sums)
  end

  private def record(version, sha)
    @release.record(version, sha, @now.utc.to_date)
  end

  # The runs of ci.yml in the last DAYS days.
  private def runs
    api = @env.fetch("GITHUB_API_URL", "https://api.github.com")
    github = GitHubAPI.new(repository: @env["GITHUB_REPOSITORY"], token: @env["GH_TOKEN"], api:)
    since = (@now - (DAYS * 86_400)).utc.strftime("%Y-%m-%d")
    path = "actions/workflows/ci.yml/runs"
    CommitRuns.new(github.all(path, "workflow_runs", created: ">=#{since}", exclude_pull_requests: true), github)
  end
end
