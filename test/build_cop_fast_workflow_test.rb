# frozen_string_literal: true

require_relative "test_helper"
require "yaml"

# How build-cop.yml follows fast.yml: it runs when a run of Fast ends on trunk,
# as it does when a run of CI ends, and not when one ends on a branch it
# bisects on, where each push of the cop's runs Fast and the cop has nothing
# to learn. The cop's judgment of a red Fast run rests on fast.yml giving each
# push to trunk a run of its own that nothing cancels.
class BuildCopFastWorkflowTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  private_constant(:ROOT)

  # GitHub's documentation says that a workflow_run that names several
  # workflows runs when any one of them completes.
  def test_it_follows_fast_as_well_as_ci
    trigger = workflow("build-cop.yml")[true]["workflow_run"]

    assert_equal(%w[ci.yml fast.yml].map { |name| workflow(name)["name"] }, trigger["workflows"])
  end

  def test_a_run_of_fast_on_a_bisect_branch_or_for_a_pull_request_starts_nothing
    fast = workflow("fast.yml")["name"]
    expected = "github.event_name != 'workflow_run' || (github.event.workflow_run.event != 'pull_request' " \
      "&& (github.event.workflow_run.name != '#{fast}' || github.event.workflow_run.head_branch == 'trunk'))"

    assert_equal(expected, workflow("build-cop.yml").dig("jobs", "cop", "if"))
  end

  def test_fast_gives_each_push_to_trunk_a_run_of_its_own
    group = workflow("fast.yml").dig("concurrency", "group")

    assert_includes(group, "github.ref == 'refs/heads/trunk' && format('-{0}', github.sha)")
  end

  def test_fast_cancels_no_run_on_trunk
    cancel = workflow("fast.yml").dig("concurrency", "cancel-in-progress")

    assert_equal("${{ github.ref != 'refs/heads/trunk' }}", cancel)
  end

  private def workflow(name)
    YAML.load_file(File.join(ROOT, ".github", "workflows", name), aliases: true)
  end
end
