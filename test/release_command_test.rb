# frozen_string_literal: true

require "stringio"
require_relative "support/built_gem"
require_relative "support/fake_github"
require_relative "support/release_repository"
require_relative "support/served_runs"

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative "../tasks/release_command"

# The command that .github/scripts/release.sh runs: each step of a release
# reads the repository or GitHub's API and prints what the script needs.
class ReleaseCommandTest < Minitest::Test
  include ReleaseRepository
  include BuiltGem
  include ServedRuns

  NOW = Time.utc(2026, 11, 26, 12)
  private_constant(:NOW)

  def test_it_prints_the_version_a_tag_releases
    assert_equal("0.1.0\n", step("version", "v0.1.0"))
  end

  def test_it_prints_the_version_after_the_newest_release_with_no_tag
    tag("v0.4.1", commit_with("One."))

    assert_equal("0.4.2\n", step("version"))
  end

  def test_it_writes_the_notes_to_a_file
    sha = commit_with("One.")
    path = File.join(@dir, "notes.md")
    step("notes", sha, path)

    assert_equal("### Added\n\n- One.\n", File.read(path))
  end

  def test_it_writes_the_version_into_the_version_file
    commit_with("One.")
    step("stamp", "0.2.0")

    assert_equal(version_file("0.2.0"), working_copy(VERSION_FILE))
  end

  def test_it_records_the_release_dated_the_day_it_ran
    sha = commit_with("One.")
    step("record", "0.1.0", sha)

    assert_includes(working_copy(CHANGELOG), "## [0.1.0] - 2026-11-26\n")
    assert_equal(version_file("0.1.0"), working_copy(VERSION_FILE))
  end

  def test_it_checks_the_assets_and_prints_their_sums
    Dir.mktmpdir do |dir|
      gem = build_gem(dir, "stryker_for_ruby", "0.1.0")

      assert_equal("#{Digest::SHA256.file(gem).hexdigest}  stryker_for_ruby-0.1.0.gem\n", step("assets", dir, "0.1.0"))
    end
  end

  def test_it_prints_the_commit_whose_run_passed
    out = serving([passed_run(commits.last, 1)]) { step("commit", list_of_commits, nil) }

    assert_equal("#{commits.last}\n", out)
  end

  def test_it_prints_the_commit_asked_for
    out = serving([passed_run(commits.first, 1)]) { step("commit", list_of_commits, commits.first) }

    assert_equal("#{commits.first}\n", out)
  end

  def test_a_refusal_ends_the_run_with_its_reason
    assert_match(/\Av0.1.0 is not newer than v0.2.0/, failing_step({}, "version", "v0.1.0"))
  end

  def test_the_reason_is_an_error_annotation_inside_github_actions
    assert_match(/\A::error::unknown step/, failing_step({ GITHUB_ACTIONS: "true" }, "nonsense"))
  end

  def test_an_unknown_step_is_refused
    assert_match(/unknown step "nonsense"/, failing_step({}, "nonsense"))
  end

  def test_a_failure_of_githubs_api_ends_the_run_with_its_message
    error = failing_step({}, "commit", list_of_commits)

    assert_match(/GitHub's API answered 404/, error)
  end

  private def env(extra = {})
    github = { GITHUB_REPOSITORY: REPOSITORY, GH_TOKEN: "secret", GITHUB_API_URL: FakeGitHub::API }
    github.merge(extra).transform_keys(&:to_s)
  end

  private def step(*arguments)
    out = StringIO.new
    ReleaseCommand.main(arguments.compact, env:, out:, root: @work, now: NOW)
    out.string
  end

  private def failing_step(extra, *arguments)
    commit_with("One.")
    tag("v0.2.0", "HEAD")
    _out, err = capture_io do
      FakeGitHub.new({}).serving do
        assert_raises(SystemExit) { ReleaseCommand.main(arguments, env: env(extra), root: @work, now: NOW) }
      end
    end
    err
  end
end
