# frozen_string_literal: true

require_relative("../test_helper")
require "prism"
require "stryker/edit"
require "stryker/mutators/walk"
require_relative("fake_mutator")

# Helpers for the tests that walk a file with disable comments in it.
module DisabledWalk
  # A mutator that replaces each integer literal with +to+.
  def integers(name, to)
    FakeMutator.new(name) do |node, _ancestors|
      node.is_a?(Prism::IntegerNode) ? [Stryker::Edit.over(node.location, to)] : []
    end
  end

  # A mutator that removes each call.
  CALLS = FakeMutator.new("Calls") do |node, _ancestors|
    node.is_a?(Prism::CallNode) ? [Stryker::Edit.over(node.location, "nil")] : []
  end
  private_constant(:CALLS)

  def nines
    integers("Nines", "9")
  end

  def walk(source, *mutators, **)
    Stryker::Mutators::Walk.new(file: "lib/a.rb", result: Prism.parse(source), mutators:, **)
  end

  # The values of the integer literals in +source+ that stay live, in order.
  def live(source, *mutators)
    walk(source, *(mutators.empty? ? [nines] : mutators)).mutants.map do |mutant|
      source.byteslice(mutant.start_offset, 1)
    end
  end

  def ignored(source, *mutators)
    walk(source, *(mutators.empty? ? [nines] : mutators)).ignored.map do |result|
      [source.byteslice(result.mutant.start_offset, 1), result.status, result.status_reason]
    end
  end
end
