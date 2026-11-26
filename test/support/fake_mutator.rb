# frozen_string_literal: true

require_relative("../test_helper")

# A mutator for the tests of the walk: it asks its block for the edits at each
# node, so that a test says which nodes the mutator mutates, and how.
class FakeMutator
  attr_reader :name

  def initialize(name, &edits)
    @name = name
    @edits = edits
  end

  def edits(node, ancestors)
    @edits.call(node, ancestors)
  end
end
