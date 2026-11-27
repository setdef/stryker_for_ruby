# frozen_string_literal: true

require_relative("../support/cli_project")

# Checks the configuration file that `stryker run` takes as an argument, and
# the errors for a command line that Configure can't use.
class CLIFileTest < Minitest::Test
  include CLIProject

  FILE = %({ "testRunner": "rspec", "thresholds": { "break": 50 }, "mutate": ["lib/a.rb"] })
  private_constant(:FILE)

  def test_the_argument_names_the_configuration_file
    config = stryker("run", "other.json", files: { "other.json": FILE }).pipeline.config

    assert_equal("rspec", config.test_runner)
  end

  def test_flags_may_come_after_the_file
    config = stryker("run", "other.json", "--test-runner", "minitest", files: { "other.json": FILE }).pipeline.config

    assert_equal("minitest", config.test_runner)
  end

  def test_text_that_is_not_a_number_is_a_config_error_that_names_the_flag
    outcome = stryker("run", "--timeout-ms", "soon")

    assert_equal([2, nil], [outcome.status, outcome.pipeline.config])
    assert_includes(
      outcome.err,
      %("--timeout-ms" on the command line takes a number of milliseconds, 0 or more, but its value is "soon")
    )
  end

  def test_a_file_with_a_nul_byte_is_a_config_error_that_names_the_argument
    outcome = stryker("run", "a\0b.json")

    assert_equal([2, %(The configuration file "a\\u0000b.json" has a NUL byte.\n)], [outcome.status, outcome.err])
  end

  def test_two_files_are_a_usage_error
    outcome = stryker("run", "a.json", "b.json")

    assert_equal(
      [2, %(Give at most one configuration file. Run "stryker help run" for the flags.\n)],
      [outcome.status, outcome.err]
    )
  end
end
