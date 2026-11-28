# frozen_string_literal: true

require_relative("../support/cli_project")

# Checks a flag value whose bytes aren't valid UTF-8, as a command line in a
# UTF-8 locale can hold one: every flag but `--mutate` refuses it with one
# line that gives the flag, and `--mutate` keeps it as bytes, because a file
# name can hold them.
class CLIFlagBytesTest < Minitest::Test
  include CLIProject

  BAD = "x\xFF"
  private_constant(:BAD)

  def run_with(*argv)
    outcome = stryker("run", *argv)

    [outcome.status, outcome.err]
  end

  def test_a_text_flag_whose_value_is_not_utf8_is_refused_with_a_line_that_gives_the_flag
    flags = %w[--test-runner --reporters --mutator.excluded-mutations]

    assert_equal(
      flags.map { |flag| [2, %("#{flag}" on the command line has the value "x\\xFF", which isn't valid UTF-8.\n)] },
      flags.map { |flag| run_with(flag, BAD) }
    )
  end

  def test_a_number_flag_whose_value_is_not_utf8_is_a_value_of_the_wrong_type
    expected = %("--concurrency" on the command line takes a whole number of 1 or more, ) +
      %(or a percentage of the processors such as "50%", but its value is "x\\xFF".\n)

    assert_equal([2, expected], run_with("--concurrency", BAD))
  end

  def test_the_short_and_the_equals_spellings_are_refused_too
    spellings = [["-c", BAD], ["--concurrency=#{BAD}"]]

    assert_equal(
      [[2, true], [2, true]],
      spellings.map { |argv| run_with(*argv).then { |status, err| [status, err.include?(%("--concurrency"))] } }
    )
  end

  def test_a_test_file_pattern_that_is_not_utf8_is_refused_with_the_line_of_that_option
    status, err = run_with("--minitest.test-files", "test/\xFF_test.rb")

    assert_equal([2, true], [status, err.include?("which isn't valid UTF-8, and the options of a test runner cross")])
  end

  def test_a_mutate_pattern_that_is_not_utf8_is_kept_as_the_bytes_it_was_given
    outcome = stryker("run", "--mutate", "lib/\xFF.rb,lib/b.rb")

    assert_equal([0, "", ["lib/\xFF.rb".b, "lib/b.rb"]], [outcome.status, outcome.err, outcome.pipeline.config.mutate])
  end

  def test_a_flag_name_that_is_not_utf8_is_an_unknown_flag
    status, err = run_with("--no\xFF")

    assert_equal([2, true], [status, err.start_with?("Unknown flag --no")])
  end

  def test_a_configuration_file_name_that_is_not_utf8_is_read_by_its_bytes
    status, err = run_with("conf\xFF.json")

    assert_equal(2, status)
    assert_includes(err, "conf")
  end
end
