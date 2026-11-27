# frozen_string_literal: true

require_relative("../support/config_project")
require_relative("../test_helper")

# Checks that Configure refuses a name in `mutator.excludedMutations` that no
# mutator has, and lists the valid names.
class ConfigureMutatorNamesTest < Minitest::Test
  include ConfigProject

  EXCLUDED = '"mutator.excludedMutations" in stryker.config.json'
  private_constant(:EXCLUDED)

  def test_an_unknown_mutator_name_lists_the_valid_names
    valid = Stryker::Mutators::ALL.map(&:name).join(", ")
    message = refusal({ "stryker.config.json": '{ "mutator": { "excludedMutations": ["Equality"] } }' })

    assert_equal("#{EXCLUDED} has an unknown mutator name: Equality. The valid names are #{valid}.", message)
  end

  def test_several_unknown_mutator_names_are_listed_together
    valid = Stryker::Mutators::ALL.map(&:name).join(", ")
    message = refusal({ "stryker.config.json": '{ "mutator": { "excludedMutations": ["Equality", "Range"] } }' })

    assert_equal("#{EXCLUDED} has unknown mutator names: Equality, Range. The valid names are #{valid}.", message)
  end

  def test_a_mutator_name_matches_with_its_letter_case
    assert_match(
      /unknown mutator name: booleanliteral\./,
      refusal({ "stryker.config.json": '{ "mutator": { "excludedMutations": ["booleanliteral"] } }' })
    )
  end

  def test_the_names_of_every_mutator_are_valid
    names = Stryker::Mutators::ALL.map(&:name)

    assert_equal(names, configure({}, options: { :"mutator.excludedMutations" => names }).excluded_mutations)
  end

  def test_an_unknown_mutator_name_on_the_command_line_names_the_flag
    assert_match(
      /\A"--mutator.excluded-mutations" on the command line has an unknown mutator name: Nope\./,
      refusal({}, options: { :"mutator.excludedMutations" => ["Nope"] })
    )
  end
end
