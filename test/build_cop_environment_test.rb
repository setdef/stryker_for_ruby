# frozen_string_literal: true

require "stringio"
require "tmpdir"
require_relative "support/build_cop_case"

# What the build cop takes from the environment that .github/scripts/build-cop.sh
# gives it: the repository, the token, and the API's address, each with the
# default that GitHub's own runs need, and the days it reads back from.
class BuildCopEnvironmentTest < Minitest::Test
  include BuildCopCase

  ENVIRONMENT = {
    GITHUB_REPOSITORY: "setdef/stryker_for_ruby",
    GH_TOKEN: "secret",
    GITHUB_API_URL: FakeGitHub::API,
  }.freeze
  private_constant(:ENVIRONMENT)

  def test_it_asks_the_api_that_the_environment_names
    assert_equal([FakeGitHub::API.delete_prefix("https://")], asked.hosts.uniq)
  end

  def test_it_asks_github_when_the_environment_names_no_api
    assert_equal(["api.github.com"], asked(GITHUB_API_URL: nil).hosts.uniq)
  end

  def test_it_asks_with_the_token_that_the_environment_gives
    assert_equal(["Bearer secret"], asked.authorizations.uniq)
  end

  def test_it_asks_with_no_token_when_the_environment_gives_none
    assert_equal(["Bearer "], asked(GH_TOKEN: nil).authorizations.uniq)
  end

  def test_it_asks_about_the_repository_that_the_environment_names
    assert_match(%r{\A/repos/setdef/stryker_for_ruby/actions/}, asked.requests.first)
  end

  def test_it_asks_about_no_repository_when_the_environment_names_none
    assert_match(%r{\A/repos//actions/}, asked(GITHUB_REPOSITORY: nil).requests.first)
  end

  # Three whole days before the start of the day it is, in UTC.
  def test_it_reads_the_runs_of_the_last_three_days_to_the_second
    now = Time.utc(2026, 11, 22, 23, 59, 59)

    assert_match(/created=%3E%3D2026-11-19&/, asked(now:).requests.first)
  end

  def test_it_counts_the_days_back_in_utc
    now = Time.new(2026, 11, 23, 1, 0, 0, "+05:00")

    assert_match(/created=%3E%3D2026-11-19&/, asked(now:).requests.first)
  end

  def test_it_waits_five_seconds_before_it_asks_again_after_github_failed
    assert_equal(5, api_arguments[:pause])
  end

  def test_it_asks_github_unless_told_otherwise
    assert_equal("https://api.github.com", api_arguments[:api])
  end

  private def api_arguments
    arguments = nil
    GitHubAPI.stub(:new, proc { |**given| arguments = given }) { BuildCop.new(repository: "r", token: "t") }
    arguments
  end

  # Every route answers 404, which ends the run, but not before the requests
  # are written down.
  private def asked(now: NOW, **extra)
    github = FakeGitHub.new({})
    capture_io do
      github.serving { assert_raises(SystemExit) { main(extra, now) } }
    end
    github
  end

  private def main(extra, now)
    Dir.mktmpdir do |dir|
      commits = File.join(dir, "commits.txt")
      File.write(commits, "#{COMMITS.reverse.join("\n")}\n")
      reverts = File.join(dir, "reverts.txt")
      File.write(reverts, "")
      env = ENVIRONMENT.merge(extra).compact.transform_keys(&:to_s)
      BuildCop.main(commits, reverts, env:, out: StringIO.new, now:)
    end
  end
end
