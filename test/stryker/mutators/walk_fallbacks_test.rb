# frozen_string_literal: true

require_relative("../../test_helper")
require "prism"
require "stryker/edit"
require "stryker/mutators/walk"
require_relative("../../support/fake_mutator")

# Checks that a walk makes a fallback mutator's mutant only where no other
# mutant is, on its site or inside it, as CallExpression's section of
# docs/contributors/design/mutators.md says.
class WalkFallbacksTest < Minitest::Test
  # A mutator that removes each call.
  CALLS = FakeMutator.new("Calls") do |node, _ancestors|
    node.is_a?(Prism::CallNode) ? [Stryker::Edit.over(node.location, "nil")] : []
  end
  private_constant(:CALLS)

  # A mutator that renames each call to g.
  RENAMES = FakeMutator.new("Renames") do |node, _ancestors|
    node.is_a?(Prism::CallNode) ? [Stryker::Edit.over(node.message_loc, "g")] : []
  end
  private_constant(:RENAMES)

  # A mutator that replaces each integer literal with +to+.
  def integers(name, to)
    FakeMutator.new(name) do |node, _ancestors|
      node.is_a?(Prism::IntegerNode) ? [Stryker::Edit.over(node.location, to)] : []
    end
  end

  def walk(source, *mutators, fallbacks:)
    policy = Stryker::Mutators::Policy.new(fallbacks:)
    Stryker::Mutators::Walk.new(file: "lib/a.rb", result: Prism.parse(source), mutators:, policy:).mutants
  end

  def default_walk(source)
    Stryker::Mutators::Walk.new(file: "lib/a.rb", result: Prism.parse(source)).mutants
  end

  def summary(mutants)
    mutants.map { |mutant| [mutant.id, mutant.mutator_name, mutant.start_offset, mutant.replacement] }
  end

  def test_makes_a_fallbacks_mutant_where_no_other_mutant_is
    assert_equal([[1, "Calls", 0, "nil"]], summary(walk("f(:a)\n", CALLS, integers("Nines", "9"), fallbacks: [CALLS])))
  end

  def test_leaves_out_a_fallbacks_mutant_where_another_mutant_is_inside_its_site
    mutants = walk("f(1)\n", CALLS, integers("Nines", "9"), fallbacks: [CALLS])

    assert_equal([[1, "Nines", 2, "9"]], summary(mutants))
  end

  def test_leaves_out_a_fallbacks_mutant_where_another_mutator_has_a_mutant_on_its_site
    mutants = walk("f(:a)\n", CALLS, RENAMES, fallbacks: [CALLS])

    assert_equal([[1, "Renames", 0, "g"]], summary(mutants))
  end

  def test_leaves_out_a_fallbacks_mutant_where_another_of_its_own_is_inside_its_site
    assert_equal([[1, "Calls", 2, "nil"]], summary(walk("f(h(:a))\n", CALLS, fallbacks: [CALLS])))
  end

  def test_keeps_a_fallbacks_mutant_where_the_other_mutants_are_outside_its_site
    mutants = walk("x = [f(:a), 1]\n", CALLS, integers("Nines", "9"), fallbacks: [CALLS])

    assert_equal([[1, "Calls", 5, "nil"], [2, "Nines", 12, "9"]], summary(mutants))
  end

  def test_counts_a_mutant_in_the_body_of_a_heredoc_as_inside_the_call_that_holds_the_heredoc
    # The body lies after the call's last byte, but in the call's tree.
    mutants = walk("f(<<~A)\n  \#{1}\nA\n", CALLS, integers("Nines", "9"), fallbacks: [CALLS])

    assert_equal(%w[Nines], mutants.map(&:mutator_name))
  end

  def test_keeps_every_mutant_of_a_mutator_that_is_not_a_fallback
    mutants = walk("f(1)\n", CALLS, integers("Nines", "9"), fallbacks: [])

    assert_equal(%w[Calls Nines], mutants.map(&:mutator_name))
  end

  def test_makes_call_expression_a_fallback_by_default
    mutants = default_walk("validate\nnotify(\"saved\")\n")

    assert_equal([[1, "CallExpression", 0, "nil"], [2, "StringLiteral", 16, '""']], summary(mutants))
  end

  def test_keeps_the_block_statement_mutant_where_a_call_removal_would_give_the_same_file
    mutants = default_walk("def save\n  write\nend\n")

    assert_equal(%w[BlockStatement], mutants.map(&:mutator_name))
  end

  def test_leaves_out_a_type_signature_and_everything_in_its_block
    assert_empty(default_walk("sig { void }\n"))
  end
end
