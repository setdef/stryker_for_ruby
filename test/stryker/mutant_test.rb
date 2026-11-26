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

  def test_a_round_trip_through_json_gives_an_equal_mutant
    mutant = Stryker::Mutant.new(**members)

    assert_equal(mutant, Stryker::Mutant.from_json(mutant.to_json))
  end

  def test_mutants_with_different_ids_differ
    refute_equal(Stryker::Mutant.new(**members), Stryker::Mutant.new(**members, id: 8))
  end

  def mutant(**changes)
    Stryker::Mutant.new(**members, **changes)
  end

  def span(start_offset, end_offset)
    Data.define(:start_offset, :end_offset).new(start_offset:, end_offset:)
  end

  def test_edits_the_whole_file
    assert_equal("total = a - b\n", mutant.edit("total = a + b\n"))
  end

  def test_edits_a_stretch_of_the_file_that_starts_at_an_offset
    assert_equal("a - b", mutant.edit("a + b", 8))
  end

  def test_edits_by_bytes_after_a_multibyte_character
    assert_equal("é = a - b".b, mutant(start_offset: 7, end_offset: 8).edit("é = a + b"))
  end

  def test_an_edit_that_inserts_removes_nothing
    assert_equal("total = a -+ b\n", mutant(end_offset: 10).edit("total = a + b\n"))
  end

  def test_grows_by_the_bytes_it_inserts_less_the_bytes_it_removes
    assert_equal([0, 2, -1], [mutant.growth, mutant(replacement: "---").growth, mutant(replacement: "").growth])
  end

  def test_lies_inside_a_span_that_holds_the_whole_edit
    assert_equal([true, true, false], [span(8, 13), span(10, 11), span(11, 13)].map { |each| mutant.inside?(each) })
  end

  def test_covers_a_span_inside_the_edit
    assert_equal([true, false], [span(10, 11), span(8, 13)].map { |each| mutant.covers?(each) })
  end
end
