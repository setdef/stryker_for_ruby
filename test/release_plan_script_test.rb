# frozen_string_literal: true

require_relative "support/release_script_case"

# The plan step of .github/scripts/release.sh: which commit and version a run
# releases, and whether it publishes or only rehearses.
class ReleasePlanScriptTest < Minitest::Test
  include ReleaseScriptCase

  FIELDS = %w[commit version tag publish].freeze
  private_constant(:FIELDS)

  def setup
    super
    @sha = commit_with("One.")
    push_trunk
    serve_green_run(@sha)
  end

  def test_a_run_with_no_tag_is_a_dry_run_of_the_next_patch_release
    script("plan")

    assert_equal([@sha, "0.0.1", "v0.0.1", "false"], outputs.values_at(*FIELDS))
  end

  def test_a_dry_run_says_it_publishes_nothing
    assert_match(/A dry run: it would release v0.0.1 from #{@sha}, and publishes nothing/, script("plan"))
  end

  def test_a_tag_on_a_run_of_trunk_is_published
    out = script("plan", TAG: "v0.1.0")

    assert_equal([@sha, "0.1.0", "v0.1.0", "true"], outputs.values_at(*FIELDS))
    assert_includes(out, "Releasing v0.1.0 from #{@sha}.")
  end

  def test_a_tag_that_exists_at_the_commit_is_published
    git(@work, "push", "--quiet", "origin", "#{@sha}:refs/tags/v0.1.0")
    out = script("plan", TAG: "v0.1.0", COMMIT: @sha)

    assert_equal([@sha, "0.1.0", "v0.1.0", "true"], outputs.values_at(*FIELDS))
    assert_includes(out, "Releasing v0.1.0 from #{@sha}.")
  end

  def test_a_tag_that_exists_at_another_commit_ends_the_run
    other = commit_with("One.", "Two.")
    push_trunk
    git(@work, "push", "--quiet", "origin", "#{other}:refs/tags/v0.1.0")

    assert_match(/v0.1.0 exists already, at #{other}, not #{@sha}/, failing_script("plan", TAG: "v0.1.0", COMMIT: @sha))
  end

  def test_a_tag_on_a_run_of_a_branch_is_a_dry_run
    script("plan", TAG: "v0.1.0", GITHUB_REF: "refs/heads/rehearsal")

    assert_equal(["0.1.0", "false"], outputs.values_at("version", "publish"))
  end

  def test_it_releases_the_commit_asked_for
    commit_with("One.", "Two.")
    push_trunk
    script("plan", COMMIT: @sha)

    assert_equal(@sha, outputs["commit"])
  end

  def test_it_releases_a_commit_before_the_tip_when_the_tip_has_no_green_run
    commit_with("One.", "Two.")
    push_trunk
    script("plan")

    assert_equal(@sha, outputs["commit"])
  end

  def test_a_tag_that_is_not_a_version_ends_the_run
    assert_match(/is not v0.X.Y/, failing_script("plan", TAG: "v1.0.0"))
  end

  def test_a_release_that_exists_ends_the_run
    File.write(File.join(@dir, "gh.exists"), "")

    assert_match(/GitHub has a release v0.1.0 already/, failing_script("plan", TAG: "v0.1.0"))
  end

  def test_a_commit_with_no_green_run_ends_the_run
    other = commit_with("One.", "Two.")
    push_trunk

    assert_match(/#{other} has no run of ci.yml/, failing_script("plan", COMMIT: other))
  end

  def test_a_step_that_is_none_is_refused
    assert_match(/usage: release.sh/, failing_script("nonsense"))
  end
end
