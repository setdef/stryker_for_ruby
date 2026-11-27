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
    assert_equal({ **members, description: nil }, Stryker::Mutant.new(**members).to_h)
  end

  def test_holds_a_description_when_given_one
    text = "Anchor \"^\" was removed at offset 0."

    assert_equal(text, mutant(description: text).description)
  end

  def test_has_no_description_unless_given_one
    assert_nil(mutant.description)
  end

  def test_mutants_with_different_descriptions_differ
    refute_equal(mutant(description: "a"), mutant(description: "b"))
  end

  def test_a_description_survives_a_round_trip_through_json
    described = mutant(description: "Quantifier \"+\" was removed at offset 2.")

    assert_equal(described, Stryker::Mutant.from_json(described.to_json))
  end

  def test_a_mutant_that_has_no_description_reads_from_json_that_has_none_either
    json = JSON.generate(Stryker::Mutant.new(**members).as_json.except("description"))

    assert_nil(Stryker::Mutant.from_json(json).description)
  end

  def test_a_description_crosses_json_as_valid_utf8
    described = mutant(description: "Anchor \"\xFF\" was removed".b)
    crossed = Stryker::Mutant.from_json(described.to_json).description

    assert_equal(["Anchor \"\u{FFFD}\" was removed", Encoding::UTF_8], [crossed, crossed.encoding])
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

  def test_lies_inside_a_span_that_holds_the_whole_edit
    assert_equal([true, true, false], [span(8, 13), span(10, 11), span(11, 13)].map { |each| mutant.inside?(each) })
  end

  def test_covers_a_span_inside_the_edit
    assert_equal([true, false], [span(10, 11), span(8, 13)].map { |each| mutant.covers?(each) })
  end
end
