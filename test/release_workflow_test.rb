# frozen_string_literal: true

require_relative "test_helper"
require "yaml"

# release.yml: a release starts by hand, publishes only a tag on trunk, and
# gives each job only the permission it needs.
class ReleaseWorkflowTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  private_constant(:ROOT)

  def test_it_starts_by_hand_alone
    assert_equal(["workflow_dispatch"], triggers.keys)
  end

  def test_a_run_with_no_tag_is_a_dry_run_by_default
    inputs = triggers.dig("workflow_dispatch", "inputs")

    assert_equal(["", ""], [inputs["tag"]["default"], inputs["commit"]["default"]])
  end

  def test_one_release_at_a_time_and_none_cancelled
    assert_equal(["release", false], workflow["concurrency"].values_at("group", "cancel-in-progress"))
  end

  def test_no_job_has_a_permission_the_workflow_does_not_give_it
    assert_empty(workflow["permissions"])
  end

  def test_the_build_reads_runs_and_never_writes
    assert_equal(%w[read read], job("build")["permissions"].values_at("contents", "actions"))
  end

  def test_only_the_publish_and_the_record_write_the_repository
    writers = workflow["jobs"].select { |_name, job| job.dig("permissions", "contents") == "write" }

    assert_equal(%w[publish record], writers.keys)
  end

  def test_the_release_is_made_only_from_a_run_the_plan_said_publishes
    assert_equal("needs.build.outputs.publish == 'true'", job("publish")["if"])
  end

  def test_the_record_follows_the_release_and_only_when_it_was_made
    assert_equal(%w[build publish], job("record")["needs"])
  end

  def test_the_record_pushes_trunk_with_the_runs_token
    step = job("record")["steps"].last

    assert_equal("${{ github.token }}", step.dig("env", "RELEASE_PUSH_TOKEN"))
  end

  def test_no_job_keeps_credentials_in_its_checkout
    checkouts = steps.select { |step| step["uses"].to_s.start_with?("actions/checkout") }

    assert_equal([false] * 3, checkouts.map { |step| step.dig("with", "persist-credentials") })
  end

  # Each run string calls one step of the script, which the script itself lists.
  def test_each_run_string_calls_a_step_of_the_script
    runs = steps.filter_map { |step| step["run"] }
    calls = runs.grep(/release\.sh/)

    assert_equal(%w[plan build publish record], calls.map { |call| call[/release\.sh (\w+)\z/, 1] })
    assert_match(/^plan \| build \| publish \| record\)/, File.read(File.join(ROOT, ".github/scripts/release.sh")))
  end

  private def workflow
    @workflow ||= YAML.safe_load_file(File.join(ROOT, ".github/workflows/release.yml"))
  end

  # YAML reads the key on as true.
  private def triggers
    workflow[true]
  end

  private def job(name)
    workflow["jobs"][name]
  end

  private def steps
    workflow["jobs"].values.flat_map { |job| job["steps"] }
  end
end
