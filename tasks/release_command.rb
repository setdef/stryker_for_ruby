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
#   version [TAG SHA]       prints the version TAG releases at the commit SHA,
#                           or, with no tag, the version after the newest
#                           release
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

  # Runs the step +command+ with +arguments+. Raises ArgumentError for a step
  # that is not one of these, and for a step given too few or too many
  # arguments.
  def call(command = nil, *arguments)
    step = steps.fetch(command.to_s.to_sym, nil)
    raise(ArgumentError, "unknown step #{command.inspect} for #{arguments.size} arguments") unless step

    step.call(*arguments)
  end

  # The steps, by the name that .github/scripts/release.sh gives each.
  private def steps
    {
      version: method(:version),
      commit: method(:commit),
      notes: method(:notes),
      stamp: @release.method(:stamp),
      assets: method(:assets),
      record: method(:record),
    }
  end

  private def version(tag = nil, sha = nil)
    return @out.puts(@release.next_version) unless tag

    @out.puts(@release.version(tag, sha || raise(ArgumentError, "version TAG needs the COMMIT it is released at")))
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
    github = GitHubAPI.new(repository: @env.fetch("GITHUB_REPOSITORY", ""), token: @env.fetch("GH_TOKEN", ""), api:)
    since = (@now - (DAYS * 86_400)).utc.strftime("%Y-%m-%d")
    CommitRuns.new(github.runs("ci.yml", since:), github)
  end
end
