# frozen_string_literal: true

require_relative("../../test_helper")
require "prism"
require "stryker/edit"
require "stryker/mutators/candidate"
require "stryker/mutators/roster"
require_relative("../../support/fake_mutator")

# Checks which candidates become mutants, and what IDs they get.
class RosterTest < Minitest::Test
  MUTATOR = FakeMutator.new("Edits") { [] }
  private_constant(:MUTATOR)

  # The roster reads only the edit and the reason, so every candidate has the
  # same site.
  SITE = Prism.parse("x = 11\n").value
  private_constant(:SITE)

  def candidate(start_offset, end_offset, replacement, reason = nil)
    edit = Stryker::Edit.new(start_offset, end_offset, replacement)
    Stryker::Mutators::Candidate.new(mutator: MUTATOR, site: SITE, edit:, reason:)
  end

  def roster(source = "x = 11\n", first_id: 1)
    Stryker::Mutators::Roster.new(file: "lib/a.rb", source:, first_id:)
  end

  def made(candidates, source: "x = 11\n", first_id: 1)
    roster(source, first_id:).made(candidates)
  end

  def mutants(candidates, **)
    made(candidates, **).mutants
  end

  def test_makes_a_mutant_of_a_candidate_with_the_file_the_name_and_the_edit
    expected = Stryker::Mutant.new(
      id: 1, file: "lib/a.rb", mutator_name: "Edits", start_offset: 4, end_offset: 6, replacement: "9"
    )

    assert_equal([expected], mutants([candidate(4, 6, "9")]))
  end

  def test_counts_the_ids_up_from_the_first_id
    assert_equal([8, 9], mutants([candidate(4, 6, "9"), candidate(4, 6, "8")], first_id: 8).map(&:id))
  end

  def test_makes_no_mutant_of_a_candidate_that_gives_the_original_file
    assert_empty(mutants([candidate(4, 6, "11")]))
  end

  def test_makes_no_mutant_of_a_candidate_that_gives_a_file_an_earlier_candidate_gave
    # Taking either digit out of 11 gives 1.
    assert_equal([4], mutants([candidate(4, 5, ""), candidate(5, 6, "")]).map(&:start_offset))
  end

  def test_gives_the_ids_of_the_mutants_it_keeps_with_none_left_out
    found = mutants([candidate(4, 5, ""), candidate(5, 6, ""), candidate(4, 6, "9")])

    assert_equal([1, 2], found.map(&:id))
  end

  def test_compares_files_with_a_multibyte_character_by_their_bytes
    found = mutants([candidate(5, 6, ""), candidate(6, 7, "")], source: "é = 11\n")

    assert_equal([5], found.map(&:start_offset))
  end

  def test_keeps_two_candidates_that_give_different_files
    assert_equal(2, mutants([candidate(4, 5, ""), candidate(4, 6, "")]).size)
  end

  def test_files_an_ignored_candidate_apart_with_the_status_ignored_and_the_reason
    found = made([candidate(4, 5, "", "why"), candidate(4, 6, "9")])
    result = found.ignored.first

    assert_equal([1, "Ignored", "why"], [result.mutant.id, result.status, result.status_reason])
    assert_equal([2], found.mutants.map(&:id))
  end

  def test_keeps_a_live_candidate_that_gives_the_file_of_an_earlier_ignored_one
    found = made([candidate(4, 5, "", "why"), candidate(5, 6, "")])

    assert_equal([1, 2], [found.ignored.first.mutant.id, found.mutants.first.id])
  end

  def test_keeps_an_ignored_candidate_that_gives_the_file_of_an_earlier_live_one
    found = made([candidate(4, 5, ""), candidate(5, 6, "", "why")])

    assert_equal([[1], [2]], [found.mutants.map(&:id), found.ignored.map { |result| result.mutant.id }])
  end

  def test_keeps_two_ignored_candidates_that_give_the_same_file
    assert_equal(2, made([candidate(4, 5, "", "a"), candidate(5, 6, "", "b")]).ignored.size)
  end

  def test_makes_nothing_of_an_ignored_candidate_that_gives_the_original_file
    assert_empty(made([candidate(4, 6, "11", "why")]).ignored)
  end
end
