# frozen_string_literal: true

require_relative("../../support/isolation_stand_ins")
require "stryker/isolation"

# What the fork adapter does with runs of one mutant, more than once: a
# parent tells the runs in flight apart by their mutants' IDs.
class ForkPerRunRepeatedRunsTest < Minitest::Test
  include IsolationStandIns

  parallelize_me!

  def test_the_adapter_refuses_two_runs_of_one_mutant_before_it_runs_any
    results = []
    runs = [sample_run(1), sample_run(2), sample_run(1)]
    error = assert_raises(ArgumentError) { Stryker::Isolation::ForkPerRun.new("/cache").run_all(runs) { |result| results << result } }

    assert_equal(
      "Mutant 1 is in more than one run, and the fork parent tells its runs apart by mutant ID.",
      error.message
    )
    assert_empty(results)
  end
end
