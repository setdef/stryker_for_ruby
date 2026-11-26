# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/isolation/fork_per_run"
require "stryker/testing"

# The isolation contract, against the adapter that forks a child for each
# run from a parent that loaded the tests.
class ForkPerRunContractTest < Minitest::Test
  include Stryker::Testing::IsolationContract

  parallelize_me!

  def setup
    super
    skip("Windows has no fork.") unless Process.respond_to?(:fork)
  end

  def isolation_under_test(cache, root)
    Stryker::Isolation::ForkPerRun.new(cache, root)
  end

  def runs_static_mutants?
    false
  end

  # Each child's code loaded in the parent before any mutant was active, so a
  # switch in a constant's value has run already. This is why a static
  # mutant's run needs a fresh process.
  def test_a_mutant_made_active_after_the_files_loaded_misses_their_load_time_code
    result = isolated_one(Stryker::Testing::IsolationContract::SampleLibrary::STATIC, :loaded_value)

    assert_equal("Survived", result.status)
  end
end
