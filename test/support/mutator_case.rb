# frozen_string_literal: true

require_relative("../test_helper")
require "prism"
require "stryker/mutant"

# Helpers for the unit tests of one mutator. The test class defines +mutator+,
# and the helpers ask it for its edits at every node of a source, in the
# order of the tree.
module MutatorCase
  def edits(source)
    nodes_of(Prism.parse(source).value).flat_map { |node| mutator.edits(node, []) }
  end

  def replacements(source)
    edits(source).map(&:replacement)
  end

  # The whole source with each edit made, one text for each mutant.
  def mutated(source)
    edits(source).map do |edit|
      Stryker::Mutant.new(id: 0, file: "a.rb", mutator_name: mutator.name, **edit.to_h).edit(source)
    end
  end

  # Every node in +tree+, each before the nodes inside it.
  def nodes_of(tree)
    [tree, *tree.compact_child_nodes.flat_map { |child| nodes_of(child) }]
  end
end
