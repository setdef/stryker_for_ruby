# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/isolation/fresh_processes"
require "stryker/testing"

# The isolation contract, against the adapter that runs each run in a fresh
# process, on every system.
class FreshProcessesContractTest < Minitest::Test
  include Stryker::Testing::IsolationContract

  parallelize_me!

  def isolation_under_test(cache, root)
    Stryker::Isolation::FreshProcesses.new(cache, root)
  end

  def runs_static_mutants?
    true
  end

  # The mutant is active before the process starts, so the switch in a
  # constant's value takes the mutated branch while its file loads.
  def test_a_static_mutant_is_active_while_its_file_loads
    result = isolated_one(Stryker::Testing::IsolationContract::SampleLibrary::STATIC, :loaded_value)

    assert_equal("Killed", result.status)
  end
end
