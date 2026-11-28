# frozen_string_literal: true

require_relative("../support/cli_project")

# Checks that `stryker run` has no flag that OptionParser adds on its own and
# the documentation doesn't list: a word that names one is an unknown flag, and
# `--help` and `--version` take no value.
class CLIBuiltInFlagsTest < Minitest::Test
  include CLIProject

  COMPLETIONS = [
    ["--*-completion-bash=--", "--*-completion-bash"],
    ["--*-completion-bash=--m", "--*-completion-bash"],
    ["--*-completion-zsh", "--*-completion-zsh"],
    ["--*-completion-zsh=stryker:stryker", "--*-completion-zsh"],
  ].freeze
  private_constant(:COMPLETIONS)

  def test_the_completion_flags_of_the_option_parser_are_unknown_flags
    COMPLETIONS.each do |word, flag|
      outcome = stryker("run", word)

      assert_equal(
        [2, "", %(Unknown flag #{flag}. Run "stryker help run" for the flags.\n)],
        [outcome.status, outcome.out, outcome.err],
        word
      )
    end
  end

  def test_a_value_given_to_version_is_refused_as_one_given_to_help_is
    %w[--version --help].each do |flag|
      outcome = stryker("run", "#{flag}=1")

      assert_equal(
        [2, "", %(The flag #{flag} takes no value. Run "stryker help run" for the flags.\n)],
        [outcome.status, outcome.out, outcome.err],
        flag
      )
    end
  end
end
