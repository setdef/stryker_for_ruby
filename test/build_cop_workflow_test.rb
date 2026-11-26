# frozen_string_literal: true

require_relative "test_helper"

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative "../tasks/build_cop"
require "yaml"

# build-cop.yml: it follows CI by the name GitHub matches workflow_run by, on
# trunk and on the branches it bisects on, and on a schedule, since GitHub does
# not say whether a run its own token started ends with a workflow_run; a run
# by hand changes nothing unless asked; and its script starts the bisecting
# runs on the branches tasks/build_cop.rb reads them from.
class BuildCopWorkflowTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  private_constant(:ROOT)

  def test_it_follows_ci_on_trunk_and_the_bisect_branches
    trigger = workflow("build-cop.yml")[true]["workflow_run"]

    assert_equal([workflow("ci.yml")["name"]], trigger["workflows"])
    assert_equal(["trunk", "#{BuildCop::BISECT}**"], trigger["branches"])
    assert_equal(["completed"], trigger["types"])
  end

  def test_it_runs_on_a_schedule_too
    refute_empty(workflow("build-cop.yml")[true]["schedule"])
  end

  def test_a_run_by_hand_is_a_dry_run_unless_asked_otherwise
    assert(workflow("build-cop.yml")[true].dig("workflow_dispatch", "inputs", "dry-run", "default"))
  end

  # ci.yml runs on a dispatch, which is how the cop starts a run of one commit
  # on its branch, and of the revert on trunk.
  def test_ci_runs_on_the_dispatch_the_cop_starts
    assert(workflow("ci.yml")[true].key?("workflow_dispatch"))
  end

  def test_one_cop_at_a_time_and_none_cancelled
    concurrency = workflow("build-cop.yml")["concurrency"]

    assert_equal(["build-cop", false], concurrency.values_at("group", "cancel-in-progress"))
  end

  def test_it_starts_runs_with_its_own_token_which_only_reads_and_runs_jobs
    job = cop_job

    assert_empty(workflow("build-cop.yml")["permissions"])
    assert_equal(%w[read write], job["permissions"].values_at("contents", "actions"))
  end

  def test_it_pushes_with_the_apps_token_and_keeps_no_credentials
    step = cop_job["steps"].last

    assert_equal("${{ steps.push-token.outputs.token }}", step.dig("env", "BUILD_COP_PUSH_TOKEN"))
    refute(cop_job["steps"].first.dig("with", "persist-credentials"))
  end

  def test_it_asks_the_app_for_the_two_permissions_it_needs_and_no_more
    permissions = push_token_step["with"].select { |name, _value| name.start_with?("permission-") }

    assert_equal(%w[permission-contents permission-workflows], permissions.keys)
    assert_equal(%w[write write], permissions.values)
  end

  # The App's secrets belong to the environment build-cop, which only runs of
  # trunk may use.
  def test_it_names_the_environment_that_holds_the_apps_secrets
    with = push_token_step["with"]

    assert_equal("build-cop", cop_job["environment"])
    assert_equal(
      ["${{ secrets.BUILD_COP_APP_ID }}", "${{ secrets.BUILD_COP_APP_PRIVATE_KEY }}"],
      with.values_at("app-id", "private-key")
    )
  end

  # Reverting stays off until the repository variable says so.
  def test_it_reverts_only_when_the_repository_variable_says_so
    assert_equal("${{ vars.BUILD_COP_REVERT }}", cop_job["steps"].last.dig("env", "BUILD_COP_REVERT"))
  end

  def test_it_runs_its_script
    assert_equal(".github/scripts/build-cop.sh", cop_job["steps"].last["run"])
  end

  def test_its_script_bisects_on_the_branches_the_task_reads
    script = File.read(File.join(ROOT, ".github/scripts/build-cop.sh"))

    assert_includes(script, "branch=#{BuildCop::BISECT}$commit")
    assert_includes(script, "'#{BuildCop::BISECT}*'")
  end

  def test_its_script_reads_each_field_the_task_prints
    script = File.read(File.join(ROOT, ".github/scripts/build-cop.sh"))
    fields = BuildCopStep.of(:none, "").to_output.lines.map { |line| line[/\A\w+/] }

    assert_equal(fields, fields.select { |field| script.include?("$(field #{field})") })
  end

  private def cop_job
    workflow("build-cop.yml").dig("jobs", "cop")
  end

  private def push_token_step
    cop_job["steps"].find { |step| step["id"] == "push-token" }
  end

  private def workflow(name)
    YAML.load_file(File.join(ROOT, ".github", "workflows", name), aliases: true)
  end
end
