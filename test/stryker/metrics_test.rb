# frozen_string_literal: true

require_relative("../test_helper")
require "stryker/metrics"

# Checks the counts and scores that the Stryker tools share: what each status
# adds to, which mutants the score judges, and how a score reads with nothing
# to judge.
class MetricsTest < Minitest::Test
  NONE = { killed: 0, timeout: 0, survived: 0, no_coverage: 0, runtime_errors: 0, compile_errors: 0, ignored: 0 }.freeze
  private_constant(:NONE)

  def of(**given)
    Stryker::Metrics.new(**NONE, **given)
  end

  def test_counts_the_mutants_of_each_status
    counted = Stryker::Metrics.count(%w[Killed Killed Timeout Survived NoCoverage RuntimeError CompileError Ignored])

    assert_equal(
      of(killed: 2, timeout: 1, survived: 1, no_coverage: 1, runtime_errors: 1, compile_errors: 1, ignored: 1),
      counted
    )
  end

  def test_refuses_a_status_it_does_not_count
    error = assert_raises(ArgumentError) { Stryker::Metrics.count(["Pending"]) }

    assert_includes(error.message, "unknown mutant status \"Pending\"")
  end

  def test_scores_the_detected_share_of_the_valid_mutants
    assert_in_delta(50.0, of(killed: 1, timeout: 1, survived: 1, no_coverage: 1).mutation_score)
  end

  def test_scores_the_covered_code_by_leaving_out_the_mutants_no_test_reached
    assert_in_delta(66.666, of(killed: 1, timeout: 1, survived: 1, no_coverage: 1).covered_score, 0.001)
  end

  def test_leaves_the_invalid_and_ignored_mutants_out_of_both_scores
    scored = of(killed: 1, survived: 1, runtime_errors: 5, compile_errors: 5, ignored: 5)

    assert_equal([50.0, 50.0], [scored.mutation_score, scored.covered_score])
  end

  def test_has_no_score_when_no_valid_mutant_exists
    nothing = of(compile_errors: 2, ignored: 1)

    assert_equal([nil, nil], [nothing.mutation_score, nothing.covered_score])
  end

  def test_scores_the_covered_code_as_zero_when_valid_mutants_exist_but_no_test_reached_one
    assert_in_delta(0.0, of(no_coverage: 2).covered_score)
  end

  def test_totals_every_mutant_whatever_its_status
    totals = of(killed: 1, timeout: 1, survived: 1, no_coverage: 1, runtime_errors: 2, compile_errors: 3, ignored: 9)

    assert_equal(18, totals.total)
  end
end
