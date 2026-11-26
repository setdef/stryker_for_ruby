# frozen_string_literal: true

require_relative("../test_helper")
require "stryker/mutant"

# Checks that a mutant holds its ID, its file, its mutator's name, and its text
# edit, and compares by value.
class MutantTest < Minitest::Test
  def members
    {
      id: 7,
      file: "lib/invoice.rb",
      mutator_name: "ArithmeticOperator",
      start_offset: 10,
      end_offset: 11,
      replacement: "-",
    }
  end

  def test_holds_its_members
    assert_equal(members, Stryker::Mutant.new(**members).to_h)
  end

  def test_mutants_with_equal_members_are_equal
    assert_equal(Stryker::Mutant.new(**members), Stryker::Mutant.new(*members.values))
  end

  def test_mutants_with_different_ids_differ
    refute_equal(Stryker::Mutant.new(**members), Stryker::Mutant.new(**members, id: 8))
  end
end
