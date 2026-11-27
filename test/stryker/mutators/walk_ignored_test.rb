# frozen_string_literal: true

require_relative("../../test_helper")
require "prism"
require "stryker/edit"
require "stryker/mutators/walk"
require_relative("../../support/fake_mutator")

# Checks that a walk makes the mutants of an excluded mutator, and reports
# them as Ignored, as the section "Turning mutators off" of
# docs/contributors/design/mutators.md says.
class WalkIgnoredTest < Minitest::Test
  # A mutator that removes each call.
  CALLS = FakeMutator.new("Calls") do |node, _ancestors|
    node.is_a?(Prism::CallNode) ? [Stryker::Edit.over(node.location, "nil")] : []
  end
  private_constant(:CALLS)

  # A mutator that replaces each integer literal with +to+.
  def integers(name, to)
    FakeMutator.new(name) do |node, _ancestors|
      node.is_a?(Prism::IntegerNode) ? [Stryker::Edit.over(node.location, to)] : []
    end
  end

  def walk(source, *mutators, first_id: 1, fallbacks: [], excluded: [])
    policy = Stryker::Mutators::Policy.new(fallbacks:, excluded:)
    Stryker::Mutators::Walk.new(file: "lib/a.rb", result: Prism.parse(source), mutators:, first_id:, policy:)
  end

  def test_makes_the_mutants_of_an_excluded_mutator_with_the_status_ignored_and_the_reason
    ignored = walk("x = 1\n", integers("Nines", "9"), excluded: ["Nines"]).ignored

    assert_equal(
      [[1, "Nines", "Ignored", 'Ignored because of excluded mutation "Nines"']],
      ignored.map { |result| [result.mutant.id, result.mutant.mutator_name, result.status, result.status_reason] }
    )
  end

  def test_leaves_an_ignored_mutant_out_of_the_live_mutants
    found = walk("x = [1, 2]\n", integers("Nines", "9"), integers("Zeros", "0"), excluded: ["Nines"])

    assert_equal(%w[Zeros Zeros], found.mutants.map(&:mutator_name))
  end

  def test_numbers_the_live_and_ignored_mutants_together_in_the_order_of_the_mutators
    found = walk("x = 1\n", integers("Nines", "9"), integers("Zeros", "0"), first_id: 5, excluded: ["Nines"])

    assert_equal([6], found.mutants.map(&:id))
    assert_equal([5], found.ignored.map { |result| result.mutant.id })
  end

  def test_ignores_nothing_when_no_mutator_is_excluded
    assert_empty(walk("x = 1\n", integers("Nines", "9")).ignored)
  end

  def test_matches_a_name_exactly_with_its_letter_case
    found = walk("x = 1\n", integers("Nines", "9"), excluded: %w[nines NINES])

    assert_equal(%w[Nines], found.mutants.map(&:mutator_name))
  end

  def test_an_ignored_mutant_never_removes_a_live_one_that_gives_the_same_file
    found = walk("x = 1\n", integers("First", "9"), integers("Second", "9"), excluded: ["First"])

    assert_equal([[2, "Second"]], found.mutants.map { |mutant| [mutant.id, mutant.mutator_name] })
    assert_equal([1], found.ignored.map { |result| result.mutant.id })
  end

  def test_keeps_two_ignored_mutants_that_give_the_same_file
    found = walk("x = 1\n", integers("First", "9"), integers("Second", "9"), excluded: %w[First Second])

    assert_equal([1, 2], found.ignored.map { |result| result.mutant.id })
  end

  def test_makes_no_ignored_mutant_that_gives_the_original_file
    assert_empty(walk("x = 1\n", integers("Ones", "1"), excluded: ["Ones"]).ignored)
  end

  def test_an_ignored_mutant_does_not_keep_a_fallbacks_mutant_from_being_made
    found = walk("f(1)\n", CALLS, integers("Nines", "9"), fallbacks: [CALLS], excluded: ["Nines"])

    assert_equal(%w[Calls], found.mutants.map(&:mutator_name))
    assert_equal(%w[Nines], found.ignored.map { |result| result.mutant.mutator_name })
  end

  def test_makes_an_excluded_fallbacks_mutant_ignored_where_no_live_mutant_is
    found = walk("f(:a)\n", CALLS, fallbacks: [CALLS], excluded: ["Calls"])

    assert_empty(found.mutants)
    assert_equal(%w[Calls], found.ignored.map { |result| result.mutant.mutator_name })
  end

  def test_makes_no_excluded_fallbacks_mutant_where_a_live_mutant_is_inside_its_site
    found = walk("f(1)\n", CALLS, integers("Nines", "9"), fallbacks: [CALLS], excluded: ["Calls"])

    assert_empty(found.ignored)
    assert_equal(%w[Nines], found.mutants.map(&:mutator_name))
  end
end
