# frozen_string_literal: true

require_relative("../support/config_project")
require_relative("../test_helper")

# Checks that Configure refuses an option that doesn't exist, suggests the
# nearest name, and says that a name that groups options isn't one itself.
class ConfigureNamesTest < Minitest::Test
  include ConfigProject

  def test_an_unknown_option_in_a_file_suggests_the_nearest_name
    message = refusal({ "stryker.config.json": '{ "timeoutMs": 1000 }' })

    assert_equal('Unknown option "timeoutMs" in stryker.config.json. Did you mean "timeoutMS"?', message)
  end

  def test_an_unknown_option_with_no_near_name_suggests_nothing
    assert_equal(
      'Unknown option "colour" in stryker.config.json.',
      refusal({ "stryker.config.json": '{ "colour": true }' })
    )
  end

  def test_an_unknown_nested_option_suggests_the_nearest_dotted_name
    message = refusal({ "stryker.config.json": '{ "thresholds": { "hgih": 90 } }' })

    assert_equal('Unknown option "thresholds.hgih" in stryker.config.json. Did you mean "thresholds.high"?', message)
  end

  def test_an_unknown_option_on_the_command_line_names_and_suggests_flags
    message = refusal({}, options: { :testRunnr => "rspec" })

    assert_equal('Unknown option "--test-runnr" on the command line. Did you mean "--test-runner"?', message)
  end

  def test_a_name_that_groups_options_says_so_and_lists_them
    message = refusal({ "stryker.config.json": '{ "thresholds": 90 }' })

    assert_equal(
      %("thresholds" in stryker.config.json isn't an option itself. ) +
      'It groups "thresholds.high", "thresholds.low", "thresholds.break".',
      message
    )
  end
end
