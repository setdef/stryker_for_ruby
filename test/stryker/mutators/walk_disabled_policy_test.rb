# frozen_string_literal: true

require_relative("../../support/disabled_walk")
require_relative("../../test_helper")

# Checks how a disable comment works with the excluded mutators, the identical
# mutants, and the fallback mutators.
class WalkDisabledPolicyTest < Minitest::Test
  include DisabledWalk

  def test_a_comment_wins_over_the_exclusion_of_the_mutator_for_the_reason
    source = "# Stryker disable next-line Nines: because\nx = 1\n"
    policy = Stryker::Mutators::Policy.new(excluded: ["Nines"])

    assert_equal(["because"], walk(source, nines, policy:).ignored.map(&:status_reason))
  end

  def test_a_restored_mutator_is_still_ignored_when_it_is_excluded
    source = "# Stryker disable all\n# Stryker restore all\nx = 1\n"
    policy = Stryker::Mutators::Policy.new(excluded: ["Nines"])

    assert_equal(
      ['Ignored because of excluded mutation "Nines"'],
      walk(source, nines, policy:).ignored.map(&:status_reason)
    )
  end

  def test_an_ignored_mutant_never_removes_a_live_one_that_gives_the_same_file
    source = "# Stryker disable next-line First\nx = 1\n"
    found = walk(source, integers("First", "9"), integers("Second", "9"))

    assert_equal(%w[Second], found.mutants.map(&:mutator_name))
    assert_equal([1], found.ignored.map { |result| result.mutant.id })
  end

  def test_an_ignored_mutant_does_not_keep_a_fallbacks_mutant_from_being_made
    source = "# Stryker disable next-line Nines\nf(1)\n"
    policy = Stryker::Mutators::Policy.new(fallbacks: [CALLS])
    found = walk(source, CALLS, nines, policy:)

    assert_equal(%w[Calls], found.mutants.map(&:mutator_name))
    assert_equal(%w[Nines], found.ignored.map { |result| result.mutant.mutator_name })
  end

  def test_numbers_the_ignored_and_live_mutants_together
    found = walk("# Stryker disable next-line all\nx = 1\ny = 2\n", nines)

    assert_equal([1], found.ignored.map { |result| result.mutant.id })
    assert_equal([2], found.mutants.map(&:id))
  end

  def test_marks_the_equality_mutants_of_a_line_and_leaves_its_conditional_mutants_live
    source = "# Stryker disable next-line EqualityOperator: at FREE_HOURS both branches give 0\n" \
      "fee = (hours > FREE_HOURS) ? (hours - FREE_HOURS) * RATE : 0\n"
    found = Stryker::Mutators::Walk.new(file: "lib/fee.rb", result: Prism.parse(source))

    assert_equal(%w[EqualityOperator EqualityOperator], found.ignored.map { |result| result.mutant.mutator_name })
    assert_equal(["at FREE_HOURS both branches give 0"] * 2, found.ignored.map(&:status_reason))
    assert_includes(found.mutants.map(&:mutator_name), "ConditionalExpression")
  end
end
