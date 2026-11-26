# frozen_string_literal: true

require_relative("../support/sample_values")
require_relative("../test_helper")

# Checks that a mutant run holds its mutant, kind, tests, covering tests, and
# time limit, compares by value, and survives a round trip through JSON.
class MutantRunTest < Minitest::Test
  include SampleValues

  def test_holds_its_members
    assert_equal(
      {
        mutant:,
        static: false,
        test_ids: ["Shop::DiscountTest#test_rate"],
        covered_by: ["Shop::DiscountTest#test_rate"],
        timeout_ms: 1500,
      },
      mutant_run.to_h
    )
  end

  def test_runs_with_equal_members_are_equal
    assert_equal(mutant_run, Stryker::MutantRun.new(*mutant_run.to_h.values))
  end

  def test_runs_with_different_time_limits_differ
    refute_equal(mutant_run, Stryker::MutantRun.new(**mutant_run.to_h, timeout_ms: 2000))
  end

  def test_a_round_trip_through_json_gives_an_equal_run
    assert_equal(mutant_run, Stryker::MutantRun.from_json(mutant_run.to_json))
  end

  def test_a_static_run_survives_a_round_trip
    run = Stryker::MutantRun.new(**mutant_run.to_h, static: true)

    assert_equal(run, Stryker::MutantRun.from_json(run.to_json))
  end

  def test_a_static_run_can_cover_fewer_tests_than_it_runs
    tests = { static: true, test_ids: %w[A#test_a B#test_b], covered_by: %w[B#test_b] }
    run = Stryker::MutantRun.new(**mutant_run.to_h, **tests)

    assert_equal(run, Stryker::MutantRun.from_json(run.to_json))
  end

  def test_a_missing_mutant_is_refused
    object = { static: false, test_ids: [], covered_by: [], timeout_ms: 1500 }.transform_keys(&:to_s)

    assert_raises(ArgumentError) { Stryker::MutantRun.from_h(object) }
  end
end
