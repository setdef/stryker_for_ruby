# frozen_string_literal: true

require_relative("../../test_helper")
require "stryker/edit"
require "stryker/mutators/candidate"
require "stryker/mutators/roster"
require_relative("../../support/fake_mutator")

# Checks which candidates become mutants, and what IDs they get.
class RosterTest < Minitest::Test
  MUTATOR = FakeMutator.new("Edits") { [] }
  private_constant(:MUTATOR)

  def candidate(start_offset, end_offset, replacement)
    Stryker::Mutators::Candidate.new(MUTATOR, start_offset, Stryker::Edit.new(start_offset, end_offset, replacement))
  end

  def roster(source = "x = 11\n", first_id: 1)
    Stryker::Mutators::Roster.new(file: "lib/a.rb", source:, first_id:)
  end

  def test_makes_a_mutant_of_a_candidate_with_the_file_the_name_and_the_edit
    expected = Stryker::Mutant.new(
      id: 1, file: "lib/a.rb", mutator_name: "Edits", start_offset: 4, end_offset: 6, replacement: "9"
    )

    assert_equal([expected], roster.mutants([candidate(4, 6, "9")]))
  end

  def test_counts_the_ids_up_from_the_first_id
    assert_equal([8, 9], roster(first_id: 8).mutants([candidate(4, 6, "9"), candidate(4, 6, "8")]).map(&:id))
  end

  def test_makes_no_mutant_of_a_candidate_that_gives_the_original_file
    assert_empty(roster.mutants([candidate(4, 6, "11")]))
  end

  def test_makes_no_mutant_of_a_candidate_that_gives_a_file_an_earlier_candidate_gave
    # Taking either digit out of 11 gives 1.
    mutants = roster.mutants([candidate(4, 5, ""), candidate(5, 6, "")])

    assert_equal([4], mutants.map(&:start_offset))
  end

  def test_gives_the_ids_of_the_mutants_it_keeps_with_none_left_out
    mutants = roster.mutants([candidate(4, 5, ""), candidate(5, 6, ""), candidate(4, 6, "9")])

    assert_equal([1, 2], mutants.map(&:id))
  end

  def test_compares_files_with_a_multibyte_character_by_their_bytes
    mutants = roster("é = 11\n").mutants([candidate(5, 6, ""), candidate(6, 7, "")])

    assert_equal([5], mutants.map(&:start_offset))
  end

  def test_keeps_two_candidates_that_give_different_files
    assert_equal(2, roster.mutants([candidate(4, 5, ""), candidate(4, 6, "")]).size)
  end
end
