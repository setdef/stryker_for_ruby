# frozen_string_literal: true

require_relative("../support/config_project")
require_relative("../test_helper")

# Checks that the config says which of its options a file or a flag gave, so
# that a stage can tell a value the user wrote from one that is a default.
class ConfigureGivenTest < Minitest::Test
  include ConfigProject

  def test_a_run_with_no_file_and_no_flag_is_given_nothing
    assert_empty(configure.given)
  end

  def test_an_option_in_the_file_is_given
    config = configure({ "stryker.config.json": '{ "reporters": ["json"], "thresholds": { "break": 50 } }' })

    assert_equal(%i[reporters threshold_break], config.given)
  end

  def test_an_option_on_the_command_line_is_given
    assert_equal(%i[mutate concurrency], configure(options: { mutate: ["lib/**/*.rb"], concurrency: 2 }).given)
  end

  def test_an_option_that_both_give_is_given_once
    config = configure({ "stryker.config.json": '{ "reporters": ["json"] }' }, options: { reporters: ["json"] })

    assert_equal([:reporters], config.given)
  end

  def test_an_option_that_is_given_the_value_of_its_default_is_still_given
    config = configure({ "stryker.config.json": '{ "reporters": ["clear-text", "progress", "html"] }' })

    assert_equal([:reporters], config.given)
  end

  def test_the_test_runner_is_given_when_the_file_names_it_and_not_when_the_project_folders_choose_it
    named = configure({ "stryker.config.json": '{ "testRunner": "minitest" }' })

    assert_equal([[:test_runner], []], [named.given, configure.given])
  end
end
