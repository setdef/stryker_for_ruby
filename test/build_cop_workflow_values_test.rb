# frozen_string_literal: true

require_relative "test_helper"
require "yaml"

# The expressions and values of build-cop.yml that GitHub reads, which decide
# what the build cop does with a run: whether it mints the token that pushes,
# whether the script is told to do nothing, which token each step is given,
# and what it checks out. A mistake in any of them makes the cop push when it
# should not, or never push, and no run of the script shows it, since the
# script reads only the values it is given.
class BuildCopWorkflowValuesTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  private_constant(:ROOT)

  # The token is for pushes, and a dry run pushes nothing, so a run by hand
  # that is a dry one mints none. Every other run, a schedule or a run that
  # ended, or a run by hand that is not a dry one, does.
  def test_the_token_is_minted_unless_a_run_by_hand_is_a_dry_run
    assert_equal("github.event_name != 'workflow_dispatch' || !inputs.dry-run", step("push-token")["if"])
  end

  # The script is told to do nothing only for a run by hand that asked for a
  # dry run, which is the one that has no token. GitHub gives a boolean as the
  # word the script reads: true or false.
  def test_the_script_is_told_to_do_nothing_only_for_a_run_by_hand_that_asked_for_a_dry_run
    expression = "${{ github.event_name == 'workflow_dispatch' && inputs.dry-run }}"

    assert_equal(expression, last_step.dig("env", "BUILD_COP_DRY_RUN"))
  end

  def test_a_run_by_hand_asks_for_a_dry_run_as_a_yes_or_no
    input = workflow.dig(true, "workflow_dispatch", "inputs", "dry-run")

    assert_equal(%w[boolean], [input["type"]])
  end

  def test_the_script_reads_and_runs_with_the_runs_own_token
    assert_equal("${{ github.token }}", last_step.dig("env", "GH_TOKEN"))
  end

  def test_it_checks_out_trunk_with_every_commit_for_the_revert
    with = cop_job["steps"].first["with"]

    assert_equal(["trunk", 0], with.values_at("ref", "fetch-depth"))
  end

  # The action keeps them unless it is told not to.
  def test_the_checkout_is_told_to_keep_no_credentials
    assert_same(false, cop_job["steps"].first.dig("with", "persist-credentials"))
  end

  def test_it_runs_every_half_hour
    assert_equal(["11,41 * * * *"], workflow[true]["schedule"].map { |schedule| schedule["cron"] })
  end

  def test_its_steps_run_in_bash
    assert_equal("bash", workflow.dig("defaults", "run", "shell"))
  end

  def test_it_runs_on_ubuntu_and_is_given_fifteen_minutes
    assert_equal(["ubuntu-24.04", 15], cop_job.values_at("runs-on", "timeout-minutes"))
  end

  # The job holds the App's key, so no action it runs moves under it.
  def test_every_action_it_runs_is_pinned_to_a_commit
    actions = cop_job["steps"].filter_map { |step| step["uses"] }

    assert_empty(actions.grep_v(%r{\A[\w.-]+/[\w.-]+@\h{40}\z}))
  end

  private def cop_job
    workflow.dig("jobs", "cop")
  end

  private def last_step
    cop_job["steps"].last
  end

  private def step(id)
    cop_job["steps"].find { |step| step["id"] == id }
  end

  private def workflow
    YAML.load_file(File.join(ROOT, ".github", "workflows", "build-cop.yml"), aliases: true)
  end
end
