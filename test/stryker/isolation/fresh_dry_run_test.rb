# frozen_string_literal: true

require_relative("../../support/dry_run_case")
require "stryker/isolation/fresh_processes"

# The dry run through the fresh-process adapter, in a fresh process that loads
# the project, on every system.
class FreshDryRunTest < Minitest::Test
  include DryRunCase

  parallelize_me!

  def dry_run_isolation(cache, root)
    Stryker::Isolation::FreshProcesses.new(cache, root)
  end

  # Each run, the dry run included, gets a process of its own, which loads
  # the project's tests.
  def test_the_dry_run_and_a_mutant_run_each_load_the_project
    assert_equal([["Killed"], 2], dry_run_and_mutant_run)
  end

  # The dry run is the first process to load the project's tests, so what
  # they raise while they load is what a fork parent would say of them.
  def test_tests_that_raise_while_they_load_fail_the_dry_run_as_they_fail_the_fork_parent
    error = assert_raises(Stryker::Isolation::TestsLoadError) { dry_run("  raise(KeyError, \"locale\")") }

    assert_includes(error.message, "failed to load, so no mutant can run. They raised:\nKeyError: locale")
  end

  def test_the_dry_run_needs_starting_first
    config = Stryker::Config.new(mutate: [], test_runner: "minitest")
    error = assert_raises(Stryker::Isolation::Error) { Stryker::Isolation::FreshProcesses.new(@cache, @root).dry_run(config) }

    assert_includes(error.message, "call start first")
  end
end
