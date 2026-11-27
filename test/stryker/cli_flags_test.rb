# frozen_string_literal: true

require_relative("../support/cli_project")
require "stryker/cli/flag_text"

# Checks the flags of `stryker run`: the text each one turns into a value, the
# help that lists them, and the errors for a flag the command can't use.
class CLIFlagsTest < Minitest::Test
  include CLIProject

  FlagText = Stryker::CLI::FlagText
  private_constant(:FlagText)

  def test_every_option_has_a_flag_in_the_help
    help = stryker("run", "--help").out

    Stryker::Config::OPTIONS.each_key do |option|
      flag = Stryker::Configure::Origin.flags.spell(option)

      assert_includes(help.gsub("[no-]", ""), flag, option)
    end
  end

  def test_help_in_each_spelling_lists_the_flags_on_standard_output
    [%w[run --help], %w[run -h], %w[help run], ["run", "--test-runner", "x", "-h"]].each do |argv|
      outcome = stryker(*argv)

      assert_equal([0, ""], [outcome.status, outcome.err], argv.inspect)
      assert_includes(outcome.out, "Usage: stryker run [options] [configFile]", argv.inspect)
      assert_includes(outcome.out, "--[no-]incremental", argv.inspect)
    end
  end

  def test_help_says_that_an_excluded_mutators_mutants_show_as_ignored
    help = stryker("run", "--help").out

    assert_match(/excluded-mutations NAMES\s+Mutators to turn off: their mutants show as Ignored$/, help)
  end

  def test_help_for_help_and_for_the_overview
    assert_equal(Stryker::CLI::Help.overview, stryker("help", "help").out)
  end

  def test_help_for_a_command_that_does_not_exist_is_an_unknown_command
    assert_equal(
      [2, %(Unknown command "bogus". Run "stryker help" for the commands.\n)],
      stryker("help", "bogus").then { |outcome| [outcome.status, outcome.err] }
    )
  end

  def test_an_unknown_flag_suggests_the_nearest
    outcome = stryker("run", "--test-runnr=rspec")

    assert_equal(
      [2, %(Unknown flag --test-runnr. Did you mean --test-runner? Run "stryker help run" for the flags.\n)],
      [outcome.status, outcome.err]
    )
  end

  def test_an_abbreviation_is_an_unknown_flag
    assert_includes(stryker("run", "--test").err, "Unknown flag --test.")
  end

  def test_the_no_form_of_a_switch_is_suggested
    assert_includes(stryker("run", "--no-incrementl").err, "Did you mean --no-incremental?")
  end

  def test_an_unknown_flag_far_from_every_flag_suggests_nothing
    assert_equal(
      %(Unknown flag --zzzzzzzzzzzz. Run "stryker help run" for the flags.\n),
      stryker("run", "--zzzzzzzzzzzz").err
    )
  end

  def test_a_flag_that_needs_a_value_says_so
    assert_equal(
      %(The flag --test-runner needs a value. Run "stryker help run" for the flags.\n),
      stryker("run", "--test-runner").err
    )
  end

  def test_a_flag_that_takes_no_value_says_so
    assert_equal(
      %(The flag --no-color takes no value. Run "stryker help run" for the flags.\n),
      stryker("run", "--no-color=yes").err
    )
  end

  def test_whole_text_becomes_an_integer_and_decimal_text_a_float
    assert_equal([80, -5, 80.5, 1000.0], %w[80 -5 80.5 1e3].map { |word| FlagText.number(word) })
  end

  def test_other_text_stays_text_for_the_config_check_to_name
    assert_equal(%w[abc 0x10 50% 1_000 NaN], %w[abc 0x10 50% 1_000 NaN].map { |word| FlagText.number(word) })
  end

  def test_none_is_nil_and_any_other_text_is_a_number
    assert_equal([nil, 7], [FlagText.number_or_none("none"), FlagText.number_or_none("7")])
  end

  def test_a_list_splits_at_commas_outside_braces_and_drops_empty_items
    assert_equal(["a", "b/{c,d}/*.rb", "e"], FlagText.list("a,,b/{c,d}/*.rb,e,"))
  end

  def test_an_unmatched_closing_brace_does_not_stop_the_split
    assert_equal(["a}", "b"], FlagText.list("a},b"))
  end

  def test_text_is_itself
    assert_equal("rspec", FlagText.text("rspec"))
  end
end
