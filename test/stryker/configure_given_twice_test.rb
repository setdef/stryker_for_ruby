# frozen_string_literal: true

require_relative("../support/config_project")
require_relative("../test_helper")

# Checks that Configure refuses a file that gives one option in both of its
# spellings, a nested one and a dotted one, and names both keys.
class ConfigureGivenTwiceTest < Minitest::Test
  include ConfigProject

  def test_a_nested_key_and_a_dotted_key_for_one_option_are_refused_naming_both
    json = '{ "thresholds": { "break": 5 }, "thresholds.break": 7 }'

    assert_equal(
      '"thresholds.break" in stryker.config.json is given twice, as "break" inside "thresholds" ' \
        'and as "thresholds.break". Give it once.',
      refusal({ "stryker.config.json": json })
    )
  end

  def test_the_keys_are_named_in_the_order_the_file_gives_them
    json = '{ "thresholds.break": 7, "thresholds": { "break": 5 } }'

    assert_equal(
      '"thresholds.break" in stryker.config.json is given twice, as "thresholds.break" ' \
        'and as "break" inside "thresholds". Give it once.',
      refusal({ "stryker.config.json": json })
    )
  end

  def test_a_yaml_file_that_gives_an_option_twice_is_refused_too
    yaml = "mutator:\n  excludedMutations: []\nmutator.excludedMutations: [BooleanLiteral]\n"

    assert_equal(
      '"mutator.excludedMutations" in stryker.config.yml is given twice, as "excludedMutations" inside ' \
        '"mutator" and as "mutator.excludedMutations". Give it once.',
      refusal({ "stryker.config.yml": yaml })
    )
  end

  def test_each_option_given_twice_has_its_line
    json = '{ "thresholds": { "break": 5, "low": 1 }, "thresholds.break": 7, "thresholds.low": 2 }'

    assert_equal(2, refusal({ "stryker.config.json": json }).lines.count)
  end

  def test_the_two_spellings_for_different_options_are_accepted
    json = '{ "thresholds": { "high": 90 }, "thresholds.low": 70 }'
    config = configure({ "stryker.config.json": json })

    assert_equal([90, 70], [config.threshold_high, config.threshold_low])
  end

  def test_a_flag_over_the_file_is_not_an_option_given_twice
    json = '{ "thresholds": { "break": 5 } }'

    assert_equal(7, configure({ "stryker.config.json": json }, options: { :"thresholds.break" => 7 }).threshold_break)
  end

  def test_an_option_that_a_flag_gives_in_two_spellings_is_refused_too
    options = { incremental: false }
    options["incremental"] = true
    message = refusal({}, options:)

    assert_equal(
      '"--incremental" on the command line is given twice, as "--incremental" and as "--incremental". Give it once.',
      message
    )
  end
end
