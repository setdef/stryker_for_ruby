# frozen_string_literal: true

require_relative("test_helper")

# SimpleCov starts in test_helper, so it must load before the code it measures.
require_relative("../tasks/critic_faults")

# Checks that the gate names each file rated below A and each smell.
class CriticFaultsTest < Minitest::Test
  # A report with the given analyzed files, as RubyCritic's JSON format has them.
  def report(*modules)
    JSON.generate(analysed_modules: modules, score: 100.0)
  end

  # One analyzed file, as RubyCritic's JSON format has it.
  def critic_module(path: "lib/a.rb", rating: "A", smells: [])
    { name: "A", path:, rating:, smells: }
  end

  # One smell, as RubyCritic's JSON format has it.
  def smell(lines: [4], type: "DuplicateMethodCall", message: "calls 'x.y' 2 times")
    locations = lines.map { |line| { path: "lib/a.rb", line: } }
    { context: "A#b", message:, type:, locations: }
  end

  def test_a_file_rated_a_with_no_smells_has_no_faults
    assert_empty(CriticFaults.in_report(report(critic_module)))
  end

  def test_a_file_rated_below_a_is_named_with_its_rating
    assert_equal(["lib/b.rb is rated B."], CriticFaults.in_report(report(critic_module(path: "lib/b.rb", rating: "B"))))
  end

  def test_a_smell_in_a_file_rated_a_is_named_with_its_place_and_type
    expected = ["lib/a.rb:4: A#b calls 'x.y' 2 times (DuplicateMethodCall)"]

    assert_equal(expected, CriticFaults.in_report(report(critic_module(smells: [smell]))))
  end

  def test_a_smell_in_two_places_names_both
    faults = CriticFaults.in_report(report(critic_module(smells: [smell(lines: [4, 9], type: "DuplicateCode")])))

    assert_equal(["lib/a.rb:4, lib/a.rb:9: A#b calls 'x.y' 2 times (DuplicateCode)"], faults)
  end

  def test_a_smell_in_many_places_names_the_first_three_and_counts_the_rest
    faults = CriticFaults.in_report(report(critic_module(smells: [smell(lines: [1, 2, 3, 4, 5])])))

    expected = ["lib/a.rb:1, lib/a.rb:2, lib/a.rb:3 and 2 more: A#b calls 'x.y' 2 times (DuplicateMethodCall)"]

    assert_equal(expected, faults)
  end

  def test_a_smell_in_exactly_three_places_names_all_three
    faults = CriticFaults.in_report(report(critic_module(smells: [smell(lines: [1, 2, 3])])))

    assert_equal(["lib/a.rb:1, lib/a.rb:2, lib/a.rb:3: A#b calls 'x.y' 2 times (DuplicateMethodCall)"], faults)
  end

  def test_a_file_below_a_lists_its_rating_before_its_smells
    faults = CriticFaults.in_report(report(critic_module(rating: "C", smells: [smell])))

    assert_equal(["lib/a.rb is rated C.", "lib/a.rb:4: A#b calls 'x.y' 2 times (DuplicateMethodCall)"], faults)
  end

  def test_every_file_is_checked
    faults = CriticFaults.in_report(report(critic_module, critic_module(path: "lib/z.rb", rating: "F")))

    assert_equal(["lib/z.rb is rated F."], faults)
  end
end
