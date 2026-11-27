# frozen_string_literal: true

require_relative("../../support/dry_run_case")
require "stryker/isolation/fork_per_run"

# The dry run through the fork adapter, with a real fork parent and its child.
# Windows has no fork.
class ForkDryRunTest < Minitest::Test
  include DryRunCase

  parallelize_me!

  def setup
    skip("Windows has no fork.") unless Process.respond_to?(:fork)
    super
  end

  def dry_run_isolation(cache, root)
    Stryker::Isolation::ForkPerRun.new(cache, root)
  end

  # The dry run is a child of the parent that forks each runtime mutant's
  # run, so the project's tests load once for both.
  def test_the_dry_run_and_a_mutant_run_load_the_project_once
    assert_equal([["Killed"], 1], dry_run_and_mutant_run)
  end
end
